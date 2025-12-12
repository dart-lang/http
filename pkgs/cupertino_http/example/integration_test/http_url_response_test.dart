// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('response', () {
    late HttpServer server;
    late HTTPURLResponse response;
    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          request.response.statusCode = 211;
          request.response.headers.set('Content-Type', 'text/fancy');
          request.response.headers.set('custom-header', 'custom-header-value');
          request.response.write('Hello World');
          await request.response.close();
        });
      final session = URLSession.sharedSession();
      final task = session.dataTaskWithRequest(
        URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')),
      )..resume();
      while (task.state !=
          NSURLSessionTaskState.NSURLSessionTaskStateCompleted) {
        // Let the event loop run.
        await Future<void>(() {});
      }
      response = task.response as HTTPURLResponse;
    });
    tearDown(() {
      server.close();
    });

    test('mimeType', () async {
      expect(response.mimeType, 'text/fancy');
    });
    test('statusCode', () async {
      expect(response.statusCode, 211);
    });
    test('expectedContentLength - no content-length header', () async {
      expect(response.expectedContentLength, -1);
    });

    test('custom set header', () async {
      expect(response.allHeaderFields['custom-header'], 'custom-header-value');
    });

    test('unset header', () async {
      expect(response.allHeaderFields['unset-header'], null);
    });

    test('toString', () async {
      response.toString(); // Just verify that there is no crash.
    });
  });
}
