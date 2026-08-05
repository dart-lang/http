// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:pool/pool.dart';

import '../transport.dart';
import 'client_pool.dart';

/// A pooled, multiplexed `http.Client` backed by HTTP/2 connections.
///
/// Every request is sent as its own HTTP/2 stream on a shared connection -
/// see [ClientPool] - dialed per `host:port` via
/// `SecureSocket.connect(..., supportedProtocols: ['h2'])`. Once a
/// connection's [maxStreamsPerConnection] concurrent streams are in use, a
/// new connection is dialed rather than queuing behind the existing one.
///
/// Being multi-host makes this safe to use as a general-purpose transport -
/// for example as the `baseClient` passed to `googleapis_auth`'s client
/// helpers, whose credential negotiation (OAuth2 token endpoint, WIF/OIDC
/// token exchange) targets different hosts than the API calls that follow.
/// A connection dialed for one host is never reused for another.
///
/// `onBadCertificate` is forwarded as-is to `SecureSocket.connect`: returning
/// `true` accepts a certificate that failed normal verification (expired,
/// self-signed, wrong host, ...). It exists for tests and trusted private
/// networks - do not use it to accept arbitrary certificates in production.
class Http2Client extends BaseClient {
  Http2Client({
    this.maxStreamsPerConnection = 100,
    this.maxIdleConnections = 1,
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

  /// The maximum number of idle connections to keep per host, per
  /// [ClientPool.maxIdleResources].
  final int maxIdleConnections;

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

  final _pools = <String, ClientPool<ClientTransportConnection>>{};
  var _closed = false;

  // Synchronous (no `await`), so concurrent requests to a new host:port
  // can't race each other into creating two pools for the same key.
  ClientPool<ClientTransportConnection> _poolFor(Uri url) {
    final key = '${url.host}:${url.port}';
    return _pools.putIfAbsent(
      key,
      () => ClientPool<ClientTransportConnection>(
        () => _handshakeGate.withResource(() => _dial(url.host, url.port)),
        maxConcurrentOperations: maxStreamsPerConnection,
        maxIdleResources: maxIdleConnections,
        destroy: (transport) => transport.finish(),
        // Never open more streams on a connection than its server allows,
        // which it can revise at any point by sending a new SETTINGS frame.
        concurrencyLimitOf: (transport) => transport.peerMaxConcurrentStreams,
      ),
    );
  }

  Future<ClientTransportConnection> _dial(String host, int port) async {
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
    return ClientTransportConnection.viaSocket(socket);
  }

  /// Sends [request] as a single HTTP/2 stream on [transport], translating
  /// between `BaseRequest`/`StreamedResponse` and http2's frames.
  Future<StreamedResponse> _sendOverHttp2(
    ClientTransportConnection transport,
    BaseRequest request,
    List<int> bodyBytes,
  ) async {
    if (!transport.isOpen) throw const _ConnectionClosedByPeer();

    // RFC 7540 8.1.2.3: ":path" must not be empty.
    final rawPath = request.url.path.isEmpty ? '/' : request.url.path;
    final path =
        request.url.hasQuery ? '$rawPath?${request.url.query}' : rawPath;

    final stream = transport.makeRequest([
      Header.ascii(':method', request.method),
      Header.ascii(':scheme', 'https'),
      Header.ascii(':authority', _authorityOf(request.url)),
      Header.ascii(':path', path),
      // HTTP/2 requires lowercase header names (RFC 7540 8.1.2), and forbids
      // connection-specific header fields (RFC 7540 8.1.2.2) - which a
      // request built for an HTTP/1.1-oriented client might still set.
      // `host` is dropped too, since `:authority` already carries it.
      for (final entry in request.headers.entries)
        if (!_connectionSpecificHeaders.contains(entry.key.toLowerCase()))
          Header.ascii(entry.key.toLowerCase(), entry.value),
    ], endStream: bodyBytes.isEmpty);

    if (bodyBytes.isNotEmpty) stream.sendData(bodyBytes, endStream: true);

    final statusCompleter = Completer<int>();
    late final StreamSubscription<StreamMessage> subscription;
    final bodyController = StreamController<List<int>>(
      onCancel: () => subscription.cancel(),
    );
    final responseHeaders = <String, String>{};

    subscription = stream.incomingMessages.listen(
      (message) {
        if (message is HeadersStreamMessage) {
          for (final header in message.headers) {
            // Not `ascii`: RFC 9113 permits arbitrary octets in field values,
            // and a decode failure here would be thrown into this handler,
            // where it becomes an uncaught async error rather than failing
            // the request.
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
                // A 1xx is informational (RFC 9113 8.1) - the real response
                // arrives in a later HEADERS frame.
                statusCompleter.complete(status);
              }
            } else {
              // Repeated fields are joined, per the `package:http` convention;
              // overwriting would silently drop e.g. a second `set-cookie`.
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
      },
      onError: (Object error, StackTrace stackTrace) {
        // Wrapped here rather than in send(): by the time the body errors,
        // send()'s future has usually already completed with the headers, so
        // this is the only place a body-stream error can be given the type
        // `Client` callers are promised.
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
      },
      cancelOnError: true,
    );

    final statusCode = await statusCompleter.future;
    return StreamedResponse(
      bodyController.stream,
      statusCode,
      contentLength: int.tryParse(responseHeaders['content-length'] ?? ''),
      // Snapshotted: trailer HEADERS frames keep adding to responseHeaders
      // after this response has been handed to the caller.
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
    Future<StreamedResponse> attempt() =>
        _poolFor(request.url).run((transport) async {
          bodyBytes ??= await request.finalize().toBytes();
          return _sendOverHttp2(transport, request, bodyBytes!);
        });

    return attempt()
        .catchError(
          (Object _) => attempt(),
          test: (error) => error is _ConnectionClosedByPeer,
        )
        // `Client` promises ClientException; without this a caller can see a
        // SocketException, a HandshakeException, or one of our own internal
        // error types.
        .catchError(
          (Object error, StackTrace stackTrace) => Error.throwWithStackTrace(
            ClientException('$error', request.url),
            stackTrace,
          ),
          test: (error) => error is! ClientException,
        );
  }

  /// Waits for in-flight requests to finish, then closes every connection.
  ///
  /// Unlike [close] (constrained by `http.Client`'s synchronous signature),
  /// this can be awaited by callers who hold a concrete [Http2Client].
  Future<void> terminate() async {
    _closed = true;
    // Snapshotted: a request already past the _closed check above - or its
    // retry - can still add a pool for a new host while this is awaiting.
    final pools = _pools.values.toList();
    _pools.clear();
    await Future.wait(pools.map((pool) => pool.terminate()));
  }

  @override
  void close() => unawaited(terminate());
}

/// Thrown by [Http2Client._sendOverHttp2] when a pooled connection turns
/// out to have already been closed by the peer (e.g. a graceful `GOAWAY`)
/// before any bytes were written for this request. [Http2Client.send]
/// catches this and retries once on whatever the pool dials next -
/// [ClientPool.run] has already marked the dead connection failed and
/// evicted it by the time the retry runs.
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
