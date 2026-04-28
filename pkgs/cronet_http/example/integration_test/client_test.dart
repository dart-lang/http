// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart';
import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:http_profile/http_profile.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

Future<void> testConformance() async {
  group('default cronet engine', () {
    group('profile enabled', () {
      final profile = HttpClientRequestProfile.profilingEnabled;
      HttpClientRequestProfile.profilingEnabled = true;
      try {
        testAll(
          CronetClient.defaultCronetEngine,
          canStreamRequestBody: false,
          canReceiveSetCookieHeaders: true,
          canSendCookieHeaders: true,
          supportsAbort: true,
        );
      } finally {
        HttpClientRequestProfile.profilingEnabled = profile;
      }
    });
    group('profile disabled', () {
      final profile = HttpClientRequestProfile.profilingEnabled;
      HttpClientRequestProfile.profilingEnabled = false;
      try {
        testAll(
          CronetClient.defaultCronetEngine,
          canStreamRequestBody: false,
          canReceiveSetCookieHeaders: true,
          canSendCookieHeaders: true,
          supportsAbort: true,
        );
      } finally {
        HttpClientRequestProfile.profilingEnabled = profile;
      }
    });
  });

  group('from cronet engine', () {
    testAll(
      () {
        final engine = CronetEngine.build(
            cacheMode: CacheMode.disabled, userAgent: 'Test Agent (Future)');
        return CronetClient.fromCronetEngine(engine);
      },
      canStreamRequestBody: false,
      canReceiveSetCookieHeaders: true,
      canSendCookieHeaders: true,
      supportsAbort: true,
    );
  });
}

Future<void> testCronetStreamedResponse() async {
  group('CronetStreamedResponse', () {
    late HttpServer server;
    late Uri serverUri;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.headers
              .set('Cache-Control', 'public, max-age=30, immutable');
          request.response.headers.set('etag', '12345');
          await request.response.close();
        });
      serverUri = Uri.http('localhost:${server.port}');
    });
    tearDown(() {
      server.close();
    });

    test('negotiatedProtocol', () async {
      final client = CronetClient.defaultCronetEngine();

      final response = await client.send(Request('GET', serverUri));
      await response.stream.drain<void>();

      expect(response.negotiatedProtocol, 'unknown');
    });

    test('receivedByteCount', () async {
      final client = CronetClient.defaultCronetEngine();

      final response = await client.send(Request('GET', serverUri));
      await response.stream.drain<void>();

      expect(response.receivedByteCount, greaterThan(0));
    });

    test('wasCached', () async {
      final engine = CronetEngine.build(
          cacheMode: CacheMode.memory, cacheMaxSize: 1024 * 1024);
      final client = CronetClient.fromCronetEngine(engine);

      final response1 = await client.send(Request('GET', serverUri));
      await response1.stream.drain<void>();
      final response2 = await client.send(Request('GET', serverUri));
      await response2.stream.drain<void>();

      expect(response1.wasCached, isFalse);
      expect(response2.wasCached, isTrue);
    });
  });
}

Future<void> testCronetExceptions() async {
  test('NetworkClientException', () async {
    final server = (await ServerSocket.bind('localhost', 0))
      ..listen((socket) async {
        socket.write('Gibberish');
        await socket.close();
      });
    addTearDown(server.close);
    final client = CronetClient.defaultCronetEngine();
    expect(
      client.send(Request('GET', Uri.http('localhost:${server.port}'))),
      throwsA(isA<NetworkClientException>()
          .having((e) => e.errorCode, 'errorCode', 11 // ERROR_OTHER
              )
          .having((e) => e.cronetInternalErrorCode, 'cronetInternalErrorCode',
              -370 // INVALID_HTTP_RESPONSE
              )
          .having((e) => e.toString(), 'toString',
              startsWith('NetworkClientException:'))),
    );
  });

  test('QuicException', () async {
    final udpSocket =
        await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(udpSocket.close);

    udpSocket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = udpSocket.receive();
        if (datagram != null) {
          udpSocket
              .send([0x01, 0x02, 0x03, 0x04], datagram.address, datagram.port);
        }
      }
    });

    final port = udpSocket.port;

    final engine = CronetEngine.build(enableQuic: true, quicHints: [
      ('127.0.0.1', port, port),
    ]);
    final client = CronetClient.fromCronetEngine(engine);

    expect(
      client.send(Request('GET', Uri.parse('https://127.0.0.1:$port'))),
      throwsA(isA<QuicException>()
          .having(
              (e) => e.errorCode, 'errorCode', 10 // ERROR_QUIC_PROTOCOL_FAILED
              )
          .having(
              (e) => e.quicDetailedErrorCode, 'quicDetailedErrorCode', isNot(0))
          .having(
              (e) => e.toString(), 'toString', startsWith('QuicException:'))),
    );
  });
}

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  await testConformance();
  await testCronetStreamedResponse();
  await testCronetExceptions();
}
