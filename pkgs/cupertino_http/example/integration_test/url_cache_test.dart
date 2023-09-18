// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('dataTaskWithCompletionHandler', () {
    late HttpServer server;
    var uncachedRequestCount = 0;

    setUp(() async {
      uncachedRequestCount = 0;
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          if (request.headers['if-none-match']?.first == '1234') {
            request.response.statusCode = 304;
            await request.response.close();
            return;
          }
          ++uncachedRequestCount;
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.headers.set('ETag', '1234');
          request.response.write('Hello World');
          await request.response.close();
        });
    });
    tearDown(() {
      server.close();
    });

    Future<void> doRequest(URLSession session) {
      final request =
          URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}'));
      final c = Completer<void>();
      session.dataTaskWithCompletionHandler(request, (d, r, e) {
        c.complete();
      }).resume();
      return c.future;
    }

    test('no cache', () async {
      final config = URLSessionConfiguration.defaultSessionConfiguration()
        ..cache = null;
      final session = URLSession.sessionWithConfiguration(config);

      await doRequest(session);
      await doRequest(session);

      expect(uncachedRequestCount, 2);
    });

    test('with cache', () async {
      final config = URLSessionConfiguration.defaultSessionConfiguration()
        ..cache = URLCache.withCapacity(memoryCapacity: 100000);
      final session = URLSession.sessionWithConfiguration(config);

      await doRequest(session);
      await doRequest(session);

      expect(uncachedRequestCount, 1);
    });
  });
}
