// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'response_body_server_vm.dart'
    if (dart.library.js_interop) 'response_body_server_web.dart';

/// Test that the [Client] can perform many concurrent HTTP requests without
/// error.
///
/// `concurrentRequests` controls the number of requests that will be made
/// simultaneously. If set too large, this may overload the HTTP server.
///
/// NOTE: These tests are not run by `testAll`.
void stressTestConcurrentRequests(Client client,
    {int numRequests = 100000, int concurrentRequests = 10}) async {
  group('stress concurrent requests', () {
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.nextAsInt}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('small response', () async {
      var requestCount = 0;
      var completeCount = 0;
      final c = Completer<void>();

      void request() {
        client.get(Uri.http(host, '/$requestCount')).then((response) {
          expect(response.statusCode, 200);
          ++completeCount;
          if (requestCount < numRequests) {
            ++requestCount;
            request();
          }
          if (completeCount == numRequests) {
            c.complete();
          }
        },
            onError: (Object e, _) =>
                c.completeError(e, StackTrace.empty)).ignore();
      }

      for (requestCount = 0;
          requestCount < concurrentRequests;
          ++requestCount) {
        request();
      }
      await c.future;
    });
  });
}
