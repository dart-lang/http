// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
      Header.ascii(':authority', request.url.host),
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
            final name = ascii.decode(header.name);
            final value = ascii.decode(header.value);
            if (name == ':status') {
              if (!statusCompleter.isCompleted) {
                statusCompleter.complete(int.parse(value));
              }
            } else {
              responseHeaders[name] = value;
            }
          }
        } else if (message is DataStreamMessage) {
          bodyController.add(message.bytes);
        }
      },
      onDone: () {
        if (!statusCompleter.isCompleted) {
          statusCompleter.completeError(
            StateError('Stream closed before a response status was received'),
          );
        }
        if (!bodyController.isClosed) bodyController.close();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!statusCompleter.isCompleted) {
          statusCompleter.completeError(error, stackTrace);
        }
        bodyController.addError(error, stackTrace);
        if (!bodyController.isClosed) bodyController.close();
      },
      cancelOnError: true,
    );

    final statusCode = await statusCompleter.future;
    return StreamedResponse(
      bodyController.stream,
      statusCode,
      headers: responseHeaders,
      request: request,
    );
  }

  /// The number of connections currently pooled, across every host.
  int get connectionCount =>
      _pools.values.fold(0, (total, pool) => total + pool.size);

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    List<int>? bodyBytes;
    Future<StreamedResponse> attempt() =>
        _poolFor(request.url).run((transport) async {
          bodyBytes ??= await request.finalize().toBytes();
          return _sendOverHttp2(transport, request, bodyBytes!);
        });

    return attempt().catchError(
      (Object _) => attempt(),
      test: (error) => error is _ConnectionClosedByPeer,
    );
  }

  /// Waits for in-flight requests to finish, then closes every connection.
  ///
  /// Unlike [close] (constrained by `http.Client`'s synchronous signature),
  /// this can be awaited by callers who hold a concrete [Http2Client].
  Future<void> terminate() async {
    for (final pool in _pools.values) {
      await pool.terminate();
    }
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
