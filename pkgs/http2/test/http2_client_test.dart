// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show ascii;
import 'dart:io';
import 'dart:math';

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
    } catch (_) {}
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

      client.close();
      await client.closed;
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

      client.close();
      await client.closed;
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
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final requestB = client.get(
        Uri.parse('https://localhost:${server.port}/b'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.connectionCount, 2);

      releaseA.complete();
      releaseB.complete();
      await Future.wait([requestA, requestB]);

      client.close();
      await client.closed;
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

      client.close();
      await client.closed;
      await server.close();
    });

    test('respects-server-advertised-max-concurrent-streams', () async {
      final release = Completer<void>();
      final server = await _RawHttp2Server.bind(
        settings: const ServerSettings(concurrentStreamLimit: 1),
        responseDelay: release.future,
      );
      final client = _testClient(
        maxStreamsPerConnection: 100,
        maxIdleConnections: 5,
      );

      final requestA = client.get(
        Uri.parse('https://localhost:${server.port}/a'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final requestB = client.get(
        Uri.parse('https://localhost:${server.port}/b'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      release.complete();
      final responses = await Future.wait([requestA, requestB]);
      expect(responses.map((r) => r.statusCode), everyElement(200));
      expect(server.connections, hasLength(2));

      expect(client.connectionCount, 2);

      client.close();
      await client.closed;
      await server.close();
    });

    test('holds-a-pool-slot-until-the-response-body-completes', () async {
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

      expect(client.connectionCount, 2);

      gate.complete();
      expect(await first.stream.bytesToString(), 'ok');
      expect(await second.stream.bytesToString(), 'ok');

      client.close();
      await client.closed;
      await server.close();
    });

    test('releases-the-slot-when-the-response-body-is-cancelled', () async {
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
      await first.stream.listen((_) {}).cancel();

      final second = await client.get(url);
      expect(second.statusCode, 200);
      expect(client.connectionCount, 1);

      gate.complete();
      client.close();
      await client.closed;
      await server.close();
    });

    test('releases-the-slot-when-the-response-body-errors', () async {
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

      gate.complete();

      final second = await client.get(url);
      expect(second.statusCode, 200);

      client.close();
      await client.closed;
      await server.close();
    });

    test('does-not-exceed-the-server-stream-limit-on-a-cold-burst', () async {
      const streamLimit = 2;
      const requestCount = 12;
      final release = Completer<void>();
      final context = _serverContext()..setAlpnProtocols(['h2'], true);
      final socket = await SecureServerSocket.bind('localhost', 0, context);

      final active = <ServerTransportConnection, int>{};
      final peak = <ServerTransportConnection, int>{};
      socket.listen((raw) {
        final connection = ServerTransportConnection.viaSocket(
          raw,
          settings: const ServerSettings(concurrentStreamLimit: streamLimit),
        );
        connection.incomingStreams.listen((stream) async {
          final now = (active[connection] ?? 0) + 1;
          active[connection] = now;
          peak[connection] = max(peak[connection] ?? 0, now);

          final messages = StreamIterator(stream.incomingMessages);
          await messages.moveNext();
          while (await messages.moveNext()) {}
          await release.future;
          stream.outgoingMessages.add(
            HeadersStreamMessage([Header.ascii(':status', '200')]),
          );
          stream.outgoingMessages.add(DataStreamMessage(ascii.encode('ok')));
          await stream.outgoingMessages.close();

          active[connection] = active[connection]! - 1;
        });
      });

      final client = _testClient(maxStreamsPerConnection: 100);
      final url = Uri.parse('https://localhost:${socket.port}/');
      final requests = List.generate(requestCount, (_) => client.get(url));

      await pumpEventQueue();
      release.complete();
      final responses = await Future.wait(requests);

      expect(responses.map((r) => r.statusCode), everyElement(200));
      expect(
        peak.values,
        everyElement(lessThanOrEqualTo(streamLimit)),
        reason: 'no connection may carry more streams than the server allows',
      );

      client.close();
      await client.closed;
      await socket.close();
    });

    test('fails-the-dial-when-the-peer-closes-before-settings', () async {
      final context = _serverContext()..setAlpnProtocols(['h2'], true);
      final socket = await SecureServerSocket.bind('localhost', 0, context);
      socket.listen((connection) => connection.destroy());

      final client = _testClient();
      await expectLater(
        client.get(Uri.parse('https://localhost:${socket.port}/')),
        throwsA(isA<ClientException>()),
      );

      client.close();
      await client.closed;
      await socket.close();
    });

    test('fails-the-dial-when-the-peer-never-sends-settings', () async {
      final context = _serverContext()..setAlpnProtocols(['h2'], true);
      final socket = await SecureServerSocket.bind('localhost', 0, context);
      final held = <SecureSocket>[];
      socket.listen(held.add);

      final client = Http2Client(
        onBadCertificate: (_) => true,
        settingsTimeout: const Duration(milliseconds: 200),
      );
      await expectLater(
        client.get(Uri.parse('https://localhost:${socket.port}/')),
        throwsA(isA<ClientException>()),
      );

      client.close();
      await client.closed;
      for (final connection in held) {
        connection.destroy();
      }
      await socket.close();
    });

    test('close-waits-for-in-flight-request', () async {
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
      client.close();
      final terminateFuture = client.closed.then((_) {
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
