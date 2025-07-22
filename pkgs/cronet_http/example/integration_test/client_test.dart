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

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  await testConformance();
  await testCronetStreamedResponse();
}
