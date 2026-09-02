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
    final key = '${url.host}:${url.port}';
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
      const ClientSettings(),
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
    List<int> bodyBytes,
  ) async {
    final transport = lease.connection;
    if (!transport.isOpen) throw const _ConnectionClosedByPeer();

    final rawPath = request.url.path.isEmpty ? '/' : request.url.path;
    final path =
        request.url.hasQuery ? '$rawPath?${request.url.query}' : rawPath;

    final stream = transport.makeRequest([
      Header.ascii(':method', request.method),
      Header.ascii(':scheme', 'https'),
      Header.ascii(':authority', _authorityOf(request.url)),
      Header.ascii(':path', path),
      for (final entry in request.headers.entries)
        if (!_connectionSpecificHeaders.contains(entry.key.toLowerCase()))
          Header.ascii(entry.key.toLowerCase(), entry.value),
    ], endStream: bodyBytes.isEmpty);

    if (bodyBytes.isNotEmpty) stream.sendData(bodyBytes, endStream: true);

    final statusCompleter = Completer<int>();
    late final StreamSubscription<StreamMessage> subscription;
    final bodyController = StreamController<List<int>>(
      onCancel: () {
        lease.release();
        stream.terminate();
        return subscription.cancel();
      },
    );
    final responseHeaders = <String, String>{};

    subscription = stream.incomingMessages.listen(
      (message) {
        if (message is HeadersStreamMessage) {
          for (final header in message.headers) {
            final name = latin1.decode(header.name);
            final value = latin1.decode(header.value);
            if (name == ':status') {
              final status = int.tryParse(value);
              if (status == null) {
                if (!statusCompleter.isCompleted) {
                  statusCompleter.completeError(
                    ClientException(
                      'Invalid HTTP/2 ":status" value "$value"',
                      request.url,
                    ),
                  );
                }
              } else if (status >= 200 && !statusCompleter.isCompleted) {
                statusCompleter.complete(status);
              }
            } else {
              responseHeaders.update(
                name,
                (existing) => '$existing, $value',
                ifAbsent: () => value,
              );
            }
          }
        } else if (message is DataStreamMessage) {
          bodyController.add(message.bytes);
        }
      },
      onDone: () {
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
      contentLength: int.tryParse(responseHeaders['content-length'] ?? ''),
      headers: Map.unmodifiable(responseHeaders),
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

    List<int>? bodyBytes;

    Future<StreamedResponse> attempt() async {
      final lease = await _poolFor(request.url).acquire();
      try {
        bodyBytes ??= await request.finalize().toBytes();
      } catch (_) {
        lease.release();
        rethrow;
      }
      try {
        return await _sendOverHttp2(lease, request, bodyBytes!);
      } catch (_) {
        lease.markFailed();
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

/// RFC 9113 8.3.1: ":authority" carries the port unless it is the default for
/// the scheme - which is always https here, so 443.
String _authorityOf(Uri url) =>
    url.port == 443 ? url.host : '${url.host}:${url.port}';

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
