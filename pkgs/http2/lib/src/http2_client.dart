// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:pool/pool.dart';

import '../transport.dart';
import 'client_pool.dart';
import 'connection.dart';

/// A pooled, multiplexed `http.Client` backed by HTTP/2 connections.
///
/// Every request is sent as its own HTTP/2 stream on a connection shared with
/// other requests to the same `host:port`. Once a connection is carrying as
/// many concurrent streams as it may - the lower of
/// [maxStreamsPerConnection] and the server's own advertised limit - another
/// connection is dialed rather than queuing behind the existing one. A
/// connection dialed for one host is never reused for another.
///
/// This client speaks only HTTP/2, and does not fall back to HTTP/1.1: a
/// server that does not negotiate `h2` over ALPN is treated as an error
/// rather than retried over HTTP/1.1.
///
/// `onBadCertificate` is forwarded as-is to `SecureSocket.connect`: returning
/// `true` accepts a certificate that failed normal verification (expired,
/// self-signed, wrong host, ...). It exists for tests and trusted private
/// networks - do not use it to accept arbitrary certificates in production.
@experimental
class Http2Client extends BaseClient {
  Http2Client({
    this.maxStreamsPerConnection = 100,
    this.maxIdleConnections = 1,
    this.settingsTimeout = const Duration(seconds: 10),
    int maxConcurrentHandshakes = 50,
    SecurityContext? context,
    bool Function(X509Certificate certificate)? onBadCertificate,
  }) : _context = context,
       _onBadCertificate = onBadCertificate,
       _handshakeGate = Pool(maxConcurrentHandshakes);

  /// The maximum number of concurrent HTTP/2 streams (i.e. requests) to
  /// multiplex onto a single connection before dialing another.
  ///
  /// An upper bound only: if a server says it accepts fewer concurrent
  /// streams than this, that smaller number is used for its connections.
  final int maxStreamsPerConnection;

  /// The maximum number of idle connections to keep per host.
  final int maxIdleConnections;

  /// How long to wait for a freshly dialed connection's peer to send its
  /// mandatory initial SETTINGS frame (RFC 7540 3.5).
  ///
  /// Until it arrives the peer's stream limit is unknown, so the connection
  /// can't be safely multiplexed onto; a peer that never sends one is
  /// abandoned rather than waited on forever.
  final Duration settingsTimeout;

  final SecurityContext? _context;

  // Forwarded to `SecureSocket.connect` as-is: returning `true` accepts a
  // certificate that failed normal verification (expired, self-signed,
  // wrong host, ...). Intended for tests and trusted private networks -
  // never use this to accept arbitrary certificates in production.
  final bool Function(X509Certificate certificate)? _onBadCertificate;

  // Caps concurrent in-flight TCP+TLS handshakes across every host,
  // independent of how many connections any one host's pool ends up
  // needing.
  final Pool _handshakeGate;

  final _pools = <String, ClientPool>{};
  var _closed = false;
  Future<void>? _shutdown;

  // Synchronous (no `await`), so concurrent requests to a new host:port
  // can't race each other into creating two pools for the same key.
  ClientPool _poolFor(Uri url) {
    final key = '${_bracketIpv6Host(url.host)}:${url.port}';
    return _pools.putIfAbsent(
      key,
      () => ClientPool(
        () => _handshakeGate.withResource(() => _dial(url.host, url.port)),
        maxConcurrentStreams: maxStreamsPerConnection,
        maxIdleConnections: maxIdleConnections,
      ),
    );
  }

  Future<ClientConnection> _dial(String host, int port) async {
    final socket = await SecureSocket.connect(
      host,
      port,
      context: _context,
      onBadCertificate: _onBadCertificate,
      supportedProtocols: ['h2'],
    );
    if (socket.selectedProtocol != 'h2') {
      socket.destroy();
      throw StateError(
        'Server did not negotiate HTTP/2 (got ${socket.selectedProtocol})',
      );
    }
    // Disable Nagle's algorithm, as dart:io's own HttpClient and HttpServer
    // do. Nagle holds back a write smaller than a full TCP segment while any
    // earlier data is unacknowledged, and the peer may in turn delay its ACK
    // (by up to 40 ms on Linux) while it waits for more data - such as the
    // rest of the frame that write would complete. HTTP/2 constantly ends
    // writes with such a short segment (HEADERS, WINDOW_UPDATE, the tail of a
    // DATA frame), and multiplexing puts many of them on one connection, so
    // with Nagle a request or upload regularly stalls until the peer's
    // delayed-ACK timer fires.
    socket.setOption(SocketOption.tcpNoDelay, true);

    // A connection can't be multiplexed onto until the peer has said how many
    // concurrent streams it allows, which it does in a SETTINGS frame sent
    // right after connecting - so wait for that before handing it to the pool.
    //
    // `onInitialPeerSettingsReceived` only ever completes successfully, never
    // with an error, so awaiting it alone would hang forever against a peer
    // that connects and then goes quiet. Watch the socket for the connection
    // dying, and cap the wait with `settingsTimeout`.
    final died = Completer<void>();
    final incoming = socket.transform(
      StreamTransformer<Uint8List, List<int>>.fromHandlers(
        handleDone: (sink) {
          if (!died.isCompleted) died.complete();
          sink.close();
        },
        handleError: (error, stackTrace, sink) {
          if (!died.isCompleted) died.completeError(error, stackTrace);
          sink.addError(error, stackTrace);
        },
      ),
    );
    unawaited(died.future.catchError((Object _) {}));

    final transport = ClientConnection(
      incoming,
      socket,
      // The protocol's default windows (65535 bytes) cap what a peer may have
      // in flight at 64 KiB per round trip, per connection. The stream window
      // also bounds how much a paused response body can hold up (see
      // `_sendOverHttp2`), and how much of a cancelled response must still be
      // read off the connection, delaying its other streams. So each stream
      // starts with a small window, which doubles every time half of it has
      // been read, up to `_maxStreamWindowSize`.
      const ClientSettings(
        streamWindowSize: _initialStreamWindowSize,
        connectionWindowSize: 16 * 1024 * 1024,
      ),
      maxStreamWindowSize: _maxStreamWindowSize,
    );
    try {
      await Future.any([
        transport.onInitialPeerSettingsReceived,
        died.future.then<void>(
          (_) =>
              throw ClientException(
                'The connection closed before the peer sent its initial '
                'SETTINGS frame.',
              ),
        ),
      ]).timeout(settingsTimeout);
    } catch (_) {
      // Not awaited: terminating writes a GOAWAY frame, and if the peer has
      // already gone that write may never complete - which would hang the
      // dial and defeat the timeout above. Cancelling the frame reader,
      // which closes the socket, happens synchronously inside terminate().
      unawaited(transport.terminate().catchError((Object _) => null));
      rethrow;
    }
    return transport;
  }

  /// Sends [request] as a single HTTP/2 stream on [lease]'s connection,
  /// translating between `BaseRequest`/`StreamedResponse` and http2's frames.
  ///
  /// Returns once the response headers arrive, but takes ownership of [lease]:
  /// the stream stays open while the body is delivered, so the slot is only
  /// released once that stream reaches a terminal state.
  Future<StreamedResponse> _sendOverHttp2(
    PoolLease lease,
    BaseRequest request,
    List<Header> requestHeaders,
    List<int> bodyBytes,
  ) async {
    final transport = lease.connection;
    if (!transport.isAlive) throw const _ConnectionClosedByPeer();
    if (!transport.isOpen) {
      throw ClientException(
        'The HTTP/2 connection is not accepting new streams.',
        request.url,
      );
    }

    final stream = transport.makeRequest(
      requestHeaders,
      endStream: bodyBytes.isEmpty,
    );

    if (bodyBytes.isNotEmpty) stream.sendData(bodyBytes, endStream: true);

    final statusCompleter = Completer<int>();
    late final StreamSubscription<StreamMessage> subscription;
    var failedLocally = false;
    // Pausing the body pauses the HTTP/2 stream, which then stops granting
    // flow-control credit (WINDOW_UPDATE, RFC 9113 5.2) once what the peer
    // was already allowed to send has arrived: a slow reader holds at most
    // the stream window in memory rather than the whole response. Until a
    // caller listens to `response.stream`, `subscription` is paused as soon as
    // final response headers arrive so unread responses cannot buffer in
    // `bodyController` without bound.
    final bodyController = StreamController<List<int>>(
      onListen: () {
        if (subscription.isPaused) subscription.resume();
      },
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
      onCancel: () {
        lease.release();
        stream.terminate();
        return subscription.cancel();
      },
    );
    final responseHeaders = <String, String>{};

    void failProtocol(String message) {
      if (failedLocally) return;
      failedLocally = true;
      final failure = ClientException(message, request.url);
      stream.terminate();
      unawaited(subscription.cancel());
      if (!statusCompleter.isCompleted) {
        statusCompleter.completeError(failure);
      } else {
        bodyController.addError(failure);
      }
      if (!bodyController.isClosed) {
        unawaited(bodyController.close());
      }
      lease.release();
    }

    subscription = stream.incomingMessages.listen(
      (message) {
        if (message is HeadersStreamMessage) {
          if (statusCompleter.isCompleted) {
            // Trailing headers do not mutate responseHeaders.
            return;
          }
          String? rawStatus;
          final blockHeaders = <String, String>{};
          for (final header in message.headers) {
            final name = latin1.decode(header.name);
            final value = latin1.decode(header.value);
            if (name == ':status') {
              if (rawStatus != null) {
                failProtocol('Duplicate HTTP/2 ":status" pseudo-header.');
                return;
              }
              rawStatus = value;
            } else if (name.startsWith(':')) {
              failProtocol('Unexpected HTTP/2 response pseudo-header "$name".');
              return;
            } else {
              blockHeaders.update(
                name,
                (existing) => '$existing, $value',
                ifAbsent: () => value,
              );
            }
          }

          final status = _parseStatusCode(rawStatus);
          if (status == null) {
            failProtocol(
              rawStatus == null
                  ? 'Missing HTTP/2 ":status" pseudo-header.'
                  : 'Invalid HTTP/2 ":status" value "$rawStatus".',
            );
            return;
          }
          if (status < 200) {
            // Ignore 1xx informational header blocks (RFC 9110 section 15.2).
            return;
          }

          final rawContentLength = blockHeaders['content-length'];
          if (rawContentLength != null &&
              _parseNonNegativeInt(rawContentLength) == null) {
            failProtocol(
              'Invalid HTTP/2 "content-length" value "$rawContentLength".',
            );
            return;
          }

          responseHeaders.addAll(blockHeaders);
          statusCompleter.complete(status);
          if (!message.endStream && !bodyController.hasListener) {
            subscription.pause();
          }
        } else if (message is DataStreamMessage) {
          if (!statusCompleter.isCompleted) {
            failProtocol(
              'Received HTTP/2 DATA frame before response ":status" headers.',
            );
            return;
          }
          bodyController.add(message.bytes);
        }
      },
      onDone: () {
        if (failedLocally) return;
        if (!statusCompleter.isCompleted) {
          statusCompleter.completeError(
            ClientException(
              'Stream closed before a response status was received',
              request.url,
            ),
          );
        }
        if (!bodyController.isClosed) {
          bodyController.close();
        }
        lease.release();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (failedLocally) return;
        if (_isConnectionFailure(transport, error)) lease.markFailed();
        final failure =
            error is ClientException
                ? error
                : ClientException('$error', request.url);
        if (!statusCompleter.isCompleted) {
          statusCompleter.completeError(failure, stackTrace);
        }
        bodyController.addError(failure, stackTrace);
        if (!bodyController.isClosed) {
          bodyController.close();
        }
        lease.release();
      },
      cancelOnError: true,
    );

    final statusCode = await statusCompleter.future;
    return StreamedResponse(
      bodyController.stream,
      statusCode,
      contentLength: _parseNonNegativeInt(responseHeaders['content-length']),
      headers: Map.unmodifiable(Map.of(responseHeaders)),
      reasonPhrase: _reasonPhrases[statusCode],
      request: request,
    );
  }

  /// The number of connections currently pooled, across every host.
  int get connectionCount => _pools.values.map((pool) => pool.size).sum;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (_closed) {
      throw ClientException(
        'HTTP request failed. Client is already closed.',
        request.url,
      );
    }
    if (request.url.scheme != 'https') {
      throw ClientException(
        'Http2Client only supports https (got "${request.url.scheme}").',
        request.url,
      );
    }
    if (!request.url.hasAuthority || request.url.host.isEmpty) {
      throw ClientException(
        'Invalid request URL: missing host authority.',
        request.url,
      );
    }
    // Validate URL, method, and caller-supplied headers before dialing, then
    // rebuild after `finalize()` so headers added during finalization (such as
    // MultipartRequest's `content-type` boundary) are included too.
    _buildOutboundHeaders(request);

    List<int>? bodyBytes;
    List<Header>? requestHeaders;

    Future<StreamedResponse> attempt() async {
      final lease = await _poolFor(request.url).acquire();
      try {
        bodyBytes ??= await request.finalize().toBytes();
        requestHeaders ??= _buildOutboundHeaders(request);
      } catch (_) {
        lease.release();
        rethrow;
      }
      try {
        return await _sendOverHttp2(
          lease,
          request,
          requestHeaders!,
          bodyBytes!,
        );
      } catch (error) {
        // A reset of just this stream says nothing about the connection, which
        // keeps serving its other streams - only drop it when it is gone.
        if (_isConnectionFailure(lease.connection, error)) lease.markFailed();
        lease.release();
        rethrow;
      }
    }

    return attempt()
        .catchError(
          (Object _) => attempt(),
          test: (error) => error is _ConnectionClosedByPeer,
        )
        .catchError(
          (Object error, StackTrace stackTrace) => Error.throwWithStackTrace(
            ClientException('$error', request.url),
            stackTrace,
          ),
          test: (error) => error is! ClientException,
        );
  }

  /// Rejects further requests, then waits for the in-flight ones to finish
  /// before closing every connection.
  ///
  /// A request counts as in-flight until its response body ends or is
  /// cancelled, so a caller holding a response it never reads will keep a
  /// connection open. Shutdown runs in the background, so this never blocks
  /// on that.
  @override
  void close() {
    _closed = true;
    _shutdown ??= _closeAll();
  }

  Future<void> _closeAll() async {
    final pools = _pools.values.toList();
    _pools.clear();
    await Future.wait(pools.map((pool) => pool.terminate()));
  }

  /// Completes once [close] has finished shutting every connection down.
  @visibleForTesting
  Future<void> get closed => _shutdown ?? Future<void>.value();
}

/// Thrown by [Http2Client._sendOverHttp2] when a pooled connection turns
/// out to have already been closed by the peer (e.g. a graceful `GOAWAY`)
/// before any bytes were written for this request. [Http2Client.send]
/// catches this and retries once on whatever the pool dials next, having
/// marked the dead connection failed so it isn't handed out again.
class _ConnectionClosedByPeer implements Exception {
  const _ConnectionClosedByPeer();

  @override
  String toString() =>
      'The pooled HTTP/2 connection was closed by the peer before this '
      'request could be sent.';
}

/// Whether [error], raised by a request on [connection], means the connection
/// itself is gone or going away - as opposed to the peer having reset just
/// that one stream (RFC 9113 5.4.2), which leaves the connection and its other
/// streams intact.
bool _isConnectionFailure(ClientConnection connection, Object error) =>
    error is TransportConnectionException ||
    error is _ConnectionClosedByPeer ||
    !connection.isAlive;

/// The receive window each stream starts with.
const _initialStreamWindowSize = 256 * 1024;

/// The largest receive window a stream grows to while its body is read.
const _maxStreamWindowSize = 4 * 1024 * 1024;

/// HTTP/2 carries no reason phrase (RFC 9113 8.3.2 dropped it as redundant
/// with the status code), so one is derived from the status instead - the same
/// approach `package:cupertino_http` takes for NSURLSession.
const _reasonPhrases = {
  100: 'Continue',
  101: 'Switching Protocols',
  200: 'OK',
  201: 'Created',
  202: 'Accepted',
  203: 'Non-Authoritative Information',
  204: 'No Content',
  205: 'Reset Content',
  206: 'Partial Content',
  300: 'Multiple Choices',
  301: 'Moved Permanently',
  302: 'Found',
  303: 'See Other',
  304: 'Not Modified',
  305: 'Use Proxy',
  307: 'Temporary Redirect',
  308: 'Permanent Redirect',
  400: 'Bad Request',
  401: 'Unauthorized',
  402: 'Payment Required',
  403: 'Forbidden',
  404: 'Not Found',
  405: 'Method Not Allowed',
  406: 'Not Acceptable',
  407: 'Proxy Authentication Required',
  408: 'Request Time-out',
  409: 'Conflict',
  410: 'Gone',
  411: 'Length Required',
  412: 'Precondition Failed',
  413: 'Request Entity Too Large',
  414: 'Request-URI Too Long',
  415: 'Unsupported Media Type',
  416: 'Requested range not satisfiable',
  417: 'Expectation Failed',
  421: 'Misdirected Request',
  422: 'Unprocessable Entity',
  426: 'Upgrade Required',
  428: 'Precondition Required',
  429: 'Too Many Requests',
  431: 'Request Header Fields Too Large',
  500: 'Internal Server Error',
  501: 'Not Implemented',
  502: 'Bad Gateway',
  503: 'Service Unavailable',
  504: 'Gateway Time-out',
  505: 'Http Version not supported',
  511: 'Network Authentication Required',
};

/// RFC 9113 8.3.1 & RFC 3986 3.2.2: ":authority" carries the host (with IPv6
/// literals enclosed in square brackets) and the port unless it is 443.
String _authorityOf(Uri url) {
  final host = _bracketIpv6Host(url.host);
  return url.port == 443 ? host : '$host:${url.port}';
}

String _bracketIpv6Host(String host) => host.contains(':') ? '[$host]' : host;

List<Header> _buildOutboundHeaders(BaseRequest request) {
  if (!_isValidToken(request.method)) {
    throw ClientException(
      'Invalid HTTP method "${request.method}".',
      request.url,
    );
  }

  final rawPath = request.url.path.isEmpty ? '/' : request.url.path;
  final path = request.url.hasQuery ? '$rawPath?${request.url.query}' : rawPath;
  if (!_isValidFieldValueString(path)) {
    throw ClientException('Invalid request path.', request.url);
  }
  final authority = _authorityOf(request.url);
  if (!_isValidFieldValueString(authority)) {
    throw ClientException('Invalid request authority.', request.url);
  }

  final connectionNominated = <String>{};
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == 'connection') {
      for (final token in entry.value.split(',')) {
        final trimmed = token.trim().toLowerCase();
        if (trimmed.isNotEmpty) connectionNominated.add(trimmed);
      }
    }
  }

  final encoded = <Header>[
    Header.ascii(':method', request.method),
    Header.ascii(':scheme', 'https'),
    Header.ascii(':authority', authority),
    Header.ascii(':path', path),
  ];

  for (final entry in request.headers.entries) {
    final key = entry.key;
    if (key.startsWith(':') || !_isValidToken(key)) {
      throw ClientException('Invalid HTTP header name "$key".', request.url);
    }
    final lowerKey = key.toLowerCase();
    final trimmedValue = _trimAsciiOws(entry.value);
    if (!_isValidFieldValueString(trimmedValue)) {
      throw ClientException(
        'Invalid HTTP header value for "$key".',
        request.url,
      );
    }
    if (_connectionSpecificHeaders.contains(lowerKey) ||
        connectionNominated.contains(lowerKey)) {
      continue;
    }
    if (lowerKey == 'te') {
      if (trimmedValue.toLowerCase() != 'trailers') {
        throw ClientException(
          'HTTP/2 only allows "te: trailers" (got "${entry.value}").',
          request.url,
        );
      }
      encoded.add(Header.ascii('te', 'trailers'));
      continue;
    }
    encoded.add(Header(ascii.encode(lowerKey), latin1.encode(trimmedValue)));
  }

  return encoded;
}

bool _isValidToken(String s) {
  if (s.isEmpty) return false;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    final isAlphaNum =
        (c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x5a) ||
        (c >= 0x61 && c <= 0x7a);
    if (isAlphaNum) continue;
    final isSymbol = switch (c) {
      0x21 ||
      0x23 ||
      0x24 ||
      0x25 ||
      0x26 ||
      0x27 ||
      0x2a ||
      0x2b ||
      0x2d ||
      0x2e ||
      0x5e ||
      0x5f ||
      0x60 ||
      0x7c ||
      0x7e => true,
      _ => false,
    };
    if (!isSymbol) return false;
  }
  return true;
}

String _trimAsciiOws(String s) {
  var start = 0;
  var end = s.length;
  while (start < end) {
    final c = s.codeUnitAt(start);
    if (c != 0x20 && c != 0x09) break;
    start++;
  }
  while (end > start) {
    final c = s.codeUnitAt(end - 1);
    if (c != 0x20 && c != 0x09) break;
    end--;
  }
  return start == 0 && end == s.length ? s : s.substring(start, end);
}

bool _isValidFieldValueString(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if ((c < 0x20 && c != 0x09) || c == 0x7f || c > 0xff) {
      return false;
    }
  }
  return true;
}

int? _parseStatusCode(String? value) {
  if (value == null || value.length != 3) return null;
  final d0 = value.codeUnitAt(0) - 0x30;
  final d1 = value.codeUnitAt(1) - 0x30;
  final d2 = value.codeUnitAt(2) - 0x30;
  if (d0 < 0 || d0 > 9 || d1 < 0 || d1 > 9 || d2 < 0 || d2 > 9) return null;
  final status = d0 * 100 + d1 * 10 + d2;
  if (status < 100 || status > 599 || status == 101) return null;
  return status;
}

int? _parseNonNegativeInt(String? value) {
  if (value == null || value.isEmpty) return null;
  var result = 0;
  for (var i = 0; i < value.length; i++) {
    final d = value.codeUnitAt(i) - 0x30;
    if (d < 0 || d > 9) return null;
    if (result > (0x7fffffffffffffff - d) ~/ 10) return null;
    result = result * 10 + d;
  }
  return result;
}

/// Header fields forbidden on an HTTP/2 stream (RFC 7540 8.1.2.2), plus
/// `host` since `:authority` already carries what it would.
const _connectionSpecificHeaders = {
  'connection',
  'keep-alive',
  'proxy-connection',
  'transfer-encoding',
  'upgrade',
  'host',
};
