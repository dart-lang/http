// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

void testCache() {
  group('cache', () {
    late HttpServer server;
    var numRequests = 0;

    setUp(() async {
      numRequests = 0;
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          ++numRequests;
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.headers
              .set('Cache-Control', 'public, max-age=30, immutable');
          request.response.headers.set('etag', '12345');
          await request.response.close();
        });
    });
    tearDown(() {
      server.close();
    });

    test('disabled', () async {
      final engine = CronetEngine.build(cacheMode: CacheMode.disabled);
      final client = CronetClient.fromCronetEngine(engine);
      await client.get(Uri.parse('http://localhost:${server.port}'));
      await client.get(Uri.parse('http://localhost:${server.port}'));
      expect(numRequests, 2);
    });

    test('memory', () async {
      final engine = CronetEngine.build(
          cacheMode: CacheMode.memory, cacheMaxSize: 1024 * 1024);
      final client = CronetClient.fromCronetEngine(engine);
      await client.get(Uri.parse('http://localhost:${server.port}'));
      await client.get(Uri.parse('http://localhost:${server.port}'));
      expect(numRequests, 1);
    });

    test('disk', () async {
      final engine = CronetEngine.build(
          cacheMode: CacheMode.disk,
          cacheMaxSize: 1024 * 1024,
          storagePath: (await Directory.systemTemp.createTemp()).absolute.path);
      final client = CronetClient.fromCronetEngine(engine);
      await client.get(Uri.parse('http://localhost:${server.port}'));
      await client.get(Uri.parse('http://localhost:${server.port}'));
      expect(numRequests, 1);
    });

    test('diskNoHttp', () async {
      final engine = CronetEngine.build(
          cacheMode: CacheMode.diskNoHttp,
          cacheMaxSize: 1024 * 1024,
          storagePath: (await Directory.systemTemp.createTemp()).absolute.path);

      final client = CronetClient.fromCronetEngine(engine);
      await client.get(Uri.parse('http://localhost:${server.port}'));
      await client.get(Uri.parse('http://localhost:${server.port}'));
      expect(numRequests, 2);
    });
  });
}

void testInvalidConfigurations() {
  group('invalidConfigurations', () {
    test('no storagePath', () async {
      expect(
          () async => CronetEngine.build(
              cacheMode: CacheMode.disk, cacheMaxSize: 1024 * 1024),
          throwsArgumentError);
    });

    test('non-existing storagePath', () async {
      expect(
          () async => CronetEngine.build(
              cacheMode: CacheMode.disk,
              cacheMaxSize: 1024 * 1024,
              storagePath: '/a/b/c/d'),
          throwsArgumentError);
    });
  });
}

void testUserAgent() {
  group('userAgent', () {
    late HttpServer server;
    late HttpHeaders requestHeaders;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          requestHeaders = request.headers;
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write('Hello World');
          await request.response.close();
        });
    });
    tearDown(() {
      server.close();
    });

    test('userAgent', () async {
      final engine = CronetEngine.build(userAgent: 'fake-agent');
      await CronetClient.fromCronetEngine(engine)
          .get(Uri.parse('http://localhost:${server.port}'));
      expect(requestHeaders['user-agent'], ['fake-agent']);
    });
  });
}

void testEngineClose() {
  group('engine close', () {
    test('multiple close', () {
      CronetEngine.build()
        ..close()
        ..close();
    });

    test('request after close', () async {
      final closedEngine = CronetEngine.build()..close();
      final client = CronetClient.fromCronetEngine(closedEngine);
      await expectLater(() => client.get(Uri.https('example.com', '/')),
          throwsA(isA<ClientException>()));
    });

    test('engine owned close', () {
      final engine = CronetEngine.build();
      CronetClient.fromCronetEngine(engine, closeEngine: true).close();
    });

    test('engine not owned close', () {
      final engine = CronetEngine.build();
      CronetClient.fromCronetEngine(engine, closeEngine: false).close();
      engine.close();
    });
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testCache();
  testInvalidConfigurations();
  testUserAgent();
  testEngineClose();
}
