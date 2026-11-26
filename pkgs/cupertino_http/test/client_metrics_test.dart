// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

void main() {
  group('onMetrics', () {
    late HttpServer server;
    late Uri uri;
    late Completer<void> finishBody;

    setUp(() async {
      finishBody = Completer<void>();
      server = await HttpServer.bind('localhost', 0)
        ..listen((request) async {
          switch (request.uri.path) {
            case '/redirect':
              await request.response.redirect(uri.replace(path: '/'));
            case '/stream':
              request.response.headers.contentType = ContentType.binary;
              request.response.headers.set('X-Content-Type-Options', 'nosniff');
              request.response.add(List.filled(65536, 0x41));
              await request.response.flush();
              await finishBody.future;
              request.response.write(' World');
              await request.response.close();
            default:
              request.response.write('Hello World');
              await request.response.close();
          }
        });
      uri = Uri.http('localhost:${server.port}', '/');
    });
    tearDown(() async {
      if (!finishBody.isCompleted) finishBody.complete();
      await server.close(force: true);
    });

    CupertinoClient createClient(CupertinoClientOnMetrics? onMetrics) {
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

    test('called once per request with the request', () async {
      final requests = <BaseRequest>[];
      final metrics = <URLSessionTaskMetrics>[];
      final client = createClient((request, task, m) {
        requests.add(request);
        metrics.add(m);
      });

      final request = Request('GET', uri);
      final response = await Response.fromStream(await client.send(request));

      expect(response.body, 'Hello World');
      expect(requests, [same(request)]);
      final transaction = metrics.single.transactionMetrics.last;
      expect(transaction.networkProtocolName, 'http/1.1');
    });

    test('correlates concurrent requests to the same URL', () async {
      final requests = <BaseRequest>[];
      final client = createClient((request, task, m) => requests.add(request));

      final first = Request('GET', uri);
      final second = Request('GET', uri);
      await Future.wait([
        client.send(first).then((r) => r.stream.drain<void>()),
        client.send(second).then((r) => r.stream.drain<void>()),
      ]);

      expect(requests, unorderedEquals([same(first), same(second)]));
    });

    test(
      'called after the body is received and before the stream closes',
      () async {
        var called = false;
        final client = createClient((request, task, m) => called = true);

        final response = await client.send(
          Request('GET', uri.replace(path: '/stream')),
        );
        expect(called, isFalse);

        final done = Completer<bool>();
        response.stream.listen((_) {
          if (!finishBody.isCompleted) finishBody.complete();
        }, onDone: () => done.complete(called));

        expect(await done.future, isTrue);
      },
    );

    test('called when the request is aborted while streaming', () async {
      final requests = <BaseRequest>[];
      final client = createClient((request, task, m) => requests.add(request));
      final abortTrigger = Completer<void>();

      final request = AbortableRequest(
        'GET',
        uri.replace(path: '/stream'),
        abortTrigger: abortTrigger.future,
      );
      final response = await client.send(request);

      final error = Completer<Object>();
      response.stream.listen((_) {
        if (!abortTrigger.isCompleted) abortTrigger.complete();
      }, onError: error.complete);

      expect(await error.future, isA<RequestAbortedException>());
      expect(requests, [same(request)]);
    });

    test('redirect', () async {
      late URLSessionTaskMetrics metrics;
      final client = createClient((request, task, m) => metrics = m);

      await client.get(uri.replace(path: '/redirect'));

      expect(metrics.redirectCount, 1);
      expect(metrics.transactionMetrics, hasLength(2));
    });
  });
}
