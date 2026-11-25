// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

void main() {
  group('onMetrics', () {
    late HttpServer server;
    late Uri uri;

    setUp(() async {
      server = await HttpServer.bind('localhost', 0)
        ..listen((request) async {
          if (request.uri.path == '/redirect') {
            await request.response.redirect(uri.replace(path: '/'));
          } else {
            request.response.write('Hello World');
            await request.response.close();
          }
        });
      uri = Uri.http('localhost:${server.port}', '/');
    });
    tearDown(() => server.close(force: true));

    CupertinoClient createClient(OnMetrics? onMetrics) {
      final client = CupertinoClient.fromSessionConfiguration(
        URLSessionConfiguration.ephemeralSessionConfiguration(),
        onMetrics: onMetrics,
      );
      addTearDown(client.close);
      return client;
    }

    test('not set', () async {
      final client = createClient(null);
      final response = await client.get(uri);
      expect(response.statusCode, 200);
      expect(response.body, 'Hello World');
    });

    test('called once per request', () async {
      final metrics = <URLSessionTaskMetrics>[];
      final tasks = <URLSessionTask>[];
      final client = createClient((session, task, m) {
        tasks.add(task);
        metrics.add(m);
      });

      final response = await client.get(uri);

      expect(response.body, 'Hello World');
      expect(metrics, hasLength(1));
      expect(tasks.single.originalRequest!.url, uri);
      final transaction = metrics.single.transactionMetrics.last;
      expect(transaction.networkProtocolName, 'http/1.1');
    });

    test('called before the response body is closed', () async {
      var called = false;
      final client = createClient((session, task, m) => called = true);

      final response = await client.send(Request('GET', uri));
      await response.stream.drain<void>();

      expect(called, isTrue);
    });

    test('connection reuse', () async {
      final reused = <bool>[];
      final client = createClient(
        (session, task, m) =>
            reused.add(m.transactionMetrics.last.reusedConnection),
      );

      await client.get(uri);
      await client.get(uri);

      expect(reused, [false, true]);
    });

    test('redirect', () async {
      late URLSessionTaskMetrics metrics;
      final client = createClient((session, task, m) => metrics = m);

      await client.get(uri.replace(path: '/redirect'));

      expect(metrics.redirectCount, 1);
      expect(metrics.transactionMetrics, hasLength(2));
    });
  });
}
