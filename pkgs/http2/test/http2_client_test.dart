// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show ascii;
import 'dart:io';

import 'package:http/http.dart' show ClientException, Request;
import 'package:http2/multiprotocol_server.dart';
import 'package:http2/src/http2_client.dart';
import 'package:http2/transport.dart';
import 'package:test/test.dart';

SecurityContext _serverContext() =>
    SecurityContext()
      ..useCertificateChain('test/certificates/server_chain.pem')
      ..usePrivateKey('test/certificates/server_key.pem', password: 'dartdart');

Future<MultiProtocolHttpServer> _bind() =>
    MultiProtocolHttpServer.bind('localhost', 0, _serverContext());

Http2Client _testClient({
  int maxStreamsPerConnection = 100,
  int maxIdleConnections = 1,
}) => Http2Client(
  maxStreamsPerConnection: maxStreamsPerConnection,
  maxIdleConnections: maxIdleConnections,
  onBadCertificate: (_) => true,
);

/// A minimal HTTP/2-only server that (unlike [MultiProtocolHttpServer])
/// exposes each accepted [ServerTransportConnection], so a test can finish
/// one connection gracefully while the server keeps listening for new ones.
class _RawHttp2Server {
  _RawHttp2Server._(
    this._socket,
    this._settings,
    this._responseDelay,
    this._bodyGate,
  ) {
    _socket.listen((socket) {
      final connection = ServerTransportConnection.viaSocket(
        socket,
        settings: _settings,
      );
      connections.add(connection);
      connection.incomingStreams.listen(
        _respondWith('ok', delay: _responseDelay, bodyGate: _bodyGate),
      );
    });
  }

  /// [settings] defaults to the same value `ServerTransportConnection` would
  /// have applied on its own, so callers that don't care are unaffected.
  static Future<_RawHttp2Server> bind({
    ServerSettings settings = const ServerSettings(concurrentStreamLimit: 1000),
    Future<void>? responseDelay,
    Future<void>? bodyGate,
  }) async {
    final context = _serverContext()..setAlpnProtocols(['h2'], true);
    final socket = await SecureServerSocket.bind('localhost', 0, context);
    return _RawHttp2Server._(socket, settings, responseDelay, bodyGate);
  }

  final SecureServerSocket _socket;
  final ServerSettings _settings;
  final Future<void>? _responseDelay;
  final Future<void>? _bodyGate;
  final connections = <ServerTransportConnection>[];

  int get port => _socket.port;

  Future<void> close() async {
    await _socket.close();
    for (final connection in connections) {
      await connection.terminate();
    }
  }
}

/// Replies with [body] after waiting on [delay], if given.
///
/// [bodyGate] holds the response open *after* its headers have been sent, so a
/// test can observe a request whose headers have arrived but whose stream is
/// still open.
void Function(ServerTransportStream) _respondWith(
  String body, {
  Future<void>? delay,
  Future<void>? bodyGate,
}) {
  return (stream) async {
    final subscription = StreamIterator(stream.incomingMessages);
    await subscription.moveNext(); // Consume the request headers.
    while (await subscription.moveNext()) {} // Drain any request body.

    if (delay != null) await delay;

    stream.outgoingMessages.add(
      HeadersStreamMessage([Header.ascii(':status', '200')]),
    );
    if (bodyGate != null) await bodyGate;
    try {
      stream.outgoingMessages.add(DataStreamMessage(ascii.encode(body)));
      await stream.outgoingMessages.close();
    } catch (_) {
      // While the body was gated the client may have reset this stream, which
      // a real server would likewise discover only on its next write.
    }
  };
}

void main() {
  group('http2-client-test', () {
    test('sends-request-and-receives-response', () async {
      final server = await _bind();
      server.startServing(
        (request) {},
        expectAsync1(_respondWith('hello'), count: 1),
      );

      final client = _testClient();
      final response = await client.get(
        Uri.parse('https://localhost:${server.port}/'),
      );

      expect(response.statusCode, 200);
      expect(response.body, 'hello');

      await client.terminate();
      await server.close();
    });

    test('pools-connections-per-host-and-port', () async {
      final serverA = await _bind();
      final serverB = await _bind();
      serverA.startServing(
        (request) {},
        expectAsync1(_respondWith('a'), count: 1),
      );
      serverB.startServing(
        (request) {},
        expectAsync1(_respondWith('b'), count: 1),
      );

      final client = _testClient();
      await Future.wait([
        client.get(Uri.parse('https://localhost:${serverA.port}/')),
        client.get(Uri.parse('https://localhost:${serverB.port}/')),
      ]);

      expect(client.connectionCount, 2);

      await client.terminate();
      await Future.wait([serverA.close(), serverB.close()]);
    });

    test('exceeding-max-streams-per-connection-opens-new-connection', () async {
      final server = await _bind();
      final releaseA = Completer<void>();
      final releaseB = Completer<void>();
      var requestNr = 0;
      server.startServing(
        (request) {},
        expectAsync1((stream) {
          final release = requestNr++ == 0 ? releaseA : releaseB;
          return _respondWith('r', delay: release.future)(stream);
        }, count: 2),
      );

      final client = _testClient(maxStreamsPerConnection: 1);
      final requestA = client.get(
        Uri.parse('https://localhost:${server.port}/a'),
      );
      // Give the pool a chance to dial and dispatch the first request
      // before the second one arrives, so it's guaranteed to land on an
      // already-full connection rather than racing to share it.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final requestB = client.get(
        Uri.parse('https://localhost:${server.port}/b'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.connectionCount, 2);

      releaseA.complete();
      releaseB.complete();
      await Future.wait([requestA, requestB]);

      await client.terminate();
      await server.close();
    });

    test('retries-once-when-pooled-connection-was-closed-by-peer', () async {
      final server = await _RawHttp2Server.bind();
      final client = _testClient();

      final r1 = await client.get(
        Uri.parse('https://localhost:${server.port}/'),
      );
      expect(r1.statusCode, 200);
      expect(client.connectionCount, 1);

      await server.connections.single.finish();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final r2 = await client.get(
        Uri.parse('https://localhost:${server.port}/'),
      );
      expect(r2.statusCode, 200);
      expect(r2.body, 'ok');

      await client.terminate();
      await server.close();
    });

    test('respects-server-advertised-max-concurrent-streams', () async {
      // The server allows a single concurrent stream, well below the 100 this
      // client would otherwise be willing to multiplex onto one connection.
      final release = Completer<void>();
      final server = await _RawHttp2Server.bind(
        settings: const ServerSettings(concurrentStreamLimit: 1),
        responseDelay: release.future,
      );
      // Idle connections are kept generously, so the assertion below reflects
      // whether a connection was evicted as *failed* rather than as excess.
      final client = _testClient(
        maxStreamsPerConnection: 100,
        maxIdleConnections: 5,
      );

      final requestA = client.get(
        Uri.parse('https://localhost:${server.port}/a'),
      );
      // Let the first request dial and occupy the server's only stream slot,
      // which also gives the peer's SETTINGS frame time to arrive.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final requestB = client.get(
        Uri.parse('https://localhost:${server.port}/b'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      release.complete();
      final responses = await Future.wait([requestA, requestB]);
      expect(responses.map((r) => r.statusCode), everyElement(200));
      expect(server.connections, hasLength(2));

      // Both connections are healthy and idle, so both should survive: the
      // first was merely at the server's stream limit, not broken.
      expect(client.connectionCount, 2);

      await client.terminate();
      await server.close();
    });

    test('holds-a-pool-slot-until-the-response-body-completes', () async {
      // Both responses send headers and then stall, so each request's h2
      // stream is still open once send() has returned.
      final gate = Completer<void>();
      final server = await _bind();
      server.startServing(
        (request) {},
        expectAsync1(_respondWith('ok', bodyGate: gate.future), count: 2),
      );

      final client = _testClient(maxStreamsPerConnection: 1);
      final url = Uri.parse('https://localhost:${server.port}/');
      final first = await client.send(Request('GET', url));
      final second = await client.send(Request('GET', url));

      // The first request still occupies its connection's only slot, so the
      // second must have been given a connection of its own.
      expect(client.connectionCount, 2);

      gate.complete();
      expect(await first.stream.bytesToString(), 'ok');
      expect(await second.stream.bytesToString(), 'ok');

      await client.terminate();
      await server.close();
    });

    test('releases-the-slot-when-the-response-body-is-cancelled', () async {
      // Only the first response is held open; the second answers normally.
      final gate = Completer<void>();
      final server = await _bind();
      var streamNr = 0;
      server.startServing(
        (request) {},
        expectAsync1((stream) {
          final held = streamNr++ == 0 ? gate.future : null;
          return _respondWith('ok', bodyGate: held)(stream);
        }, count: 2),
      );

      final client = _testClient(maxStreamsPerConnection: 1);
      final url = Uri.parse('https://localhost:${server.port}/');

      final first = await client.send(Request('GET', url));
      // Abandoning the body must hand the slot back...
      await first.stream.listen((_) {}).cancel();

      // ...so this reuses the connection rather than dialing another.
      final second = await client.get(url);
      expect(second.statusCode, 200);
      expect(client.connectionCount, 1);

      gate.complete();
      await client.terminate();
      await server.close();
    });

    test('releases-the-slot-when-the-response-body-errors', () async {
      // The body is held open, so the reset below lands mid-response rather
      // than after the stream has already finished.
      final gate = Completer<void>();
      final server = await _RawHttp2Server.bind(bodyGate: gate.future);
      final client = _testClient(maxStreamsPerConnection: 1);
      final url = Uri.parse('https://localhost:${server.port}/');

      final first = await client.send(Request('GET', url));
      await server.connections.single.terminate();
      await expectLater(
        first.stream.drain<void>(),
        throwsA(isA<ClientException>()),
      );

      // That stream is dead; let anything dialed from here answer normally.
      gate.complete();

      // The slot was handed back, so a further request can proceed.
      final second = await client.get(url);
      expect(second.statusCode, 200);

      await client.terminate();
      await server.close();
    });

    test('terminate-waits-for-in-flight-request', () async {
      final server = await _bind();
      final release = Completer<void>();
      server.startServing(
        (request) {},
        expectAsync1(_respondWith('done', delay: release.future), count: 1),
      );

      final client = _testClient();
      final request = client.get(
        Uri.parse('https://localhost:${server.port}/'),
      );

      var terminated = false;
      final terminateFuture = client.terminate().then((_) {
        terminated = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(terminated, isFalse);

      release.complete();
      await request;
      await terminateFuture;
      expect(terminated, isTrue);

      await server.close();
    });
  });
}
