// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show ascii;
import 'dart:io';

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

// test/certificates/server_chain.pem is long expired and self-signed, same
// as every other test in this package that dials it - see
// multiprotocol_server_test.dart. Bypassing verification here is just for
// this fixture; Http2Client itself defaults to real verification.
Http2Client _testClient({int maxStreamsPerConnection = 100}) => Http2Client(
  maxStreamsPerConnection: maxStreamsPerConnection,
  onBadCertificate: (_) => true,
);

/// Replies with [body] after waiting on [delay], if given.
void Function(ServerTransportStream) _respondWith(
  String body, {
  Future<void>? delay,
}) {
  return (stream) async {
    final subscription = StreamIterator(stream.incomingMessages);
    await subscription.moveNext(); // Consume the request headers.
    while (await subscription.moveNext()) {} // Drain any request body.

    if (delay != null) await delay;

    stream.outgoingMessages.add(
      HeadersStreamMessage([Header.ascii(':status', '200')]),
    );
    stream.outgoingMessages.add(DataStreamMessage(ascii.encode(body)));
    await stream.outgoingMessages.close();
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
