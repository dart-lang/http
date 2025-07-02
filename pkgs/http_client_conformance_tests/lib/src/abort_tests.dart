// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'abort_server_vm.dart'
    if (dart.library.js_interop) 'abort_server_web.dart';

/// Tests that the client supports aborting requests.
///
/// If [supportsAbort] is `false` then tests that assume that requests can be
/// aborted will be skipped.
///
/// If [canStreamResponseBody] is `false` then tests that assume that the
/// [Client] supports receiving HTTP responses with unbounded body sizes will
/// be skipped.
///
/// If [canStreamRequestBody] is `false` then tests that assume that the
/// [Client] supports sending HTTP requests with unbounded body sizes will be
/// skipped.
void testAbort(
  Client client, {
  bool supportsAbort = false,
  bool canStreamRequestBody = true,
  bool canStreamResponseBody = true,
}) {
  group('abort', () {
    late String host;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;
    late Uri serverUrl;

    setUp(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.nextAsInt}';
      serverUrl = Uri.http(host, '');
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('before request', () async {
      final abortTrigger = Completer<void>();
      final request = AbortableRequest(
        'GET',
        serverUrl,
        abortTrigger: abortTrigger.future,
      );
      abortTrigger.complete();

      expect(
        client.send(request),
        throwsA(isA<RequestAbortedException>()),
      );
    });

    test('before first streamed item', () async {
      final abortTrigger = Completer<void>();

      final request = AbortableStreamedRequest(
        'POST',
        serverUrl,
        abortTrigger: abortTrigger.future,
      );

      final response = client.send(request);

      abortTrigger.complete();

      expect(
        response,
        throwsA(isA<RequestAbortedException>()),
      );

      // Ensure that `request.sink` is still writeable after the request is
      // aborted.
      for (var i = 0; i < 1000; ++i) {
        request.sink.add('Hello World'.codeUnits);
        await Future<void>.delayed(const Duration());
      }
      await request.sink.close();
    },
        skip: supportsAbort
            ? (canStreamRequestBody ? false : 'does not stream response bodies')
            : 'does not support aborting requests');

    test('during request stream', () async {
      final abortTrigger = Completer<void>();

      final request = AbortableStreamedRequest(
        'POST',
        serverUrl,
        abortTrigger: abortTrigger.future,
      );

      final response = client.send(request);
      request.sink.add('Hello World'.codeUnits);

      abortTrigger.complete();

      expect(
        response,
        throwsA(isA<RequestAbortedException>()),
      );

      // Ensure that `request.sink` is still writeable after the request is
      // aborted.
      for (var i = 0; i < 1000; ++i) {
        request.sink.add('Hello World'.codeUnits);
        await Future<void>.delayed(const Duration());
      }
      await request.sink.close();
    },
        skip: supportsAbort
            ? (canStreamRequestBody ? false : 'does not stream request bodies')
            : 'does not support aborting requests');

    test('after response, response stream listener', () async {
      final abortTrigger = Completer<void>();

      final request = AbortableRequest(
        'GET',
        serverUrl,
        abortTrigger: abortTrigger.future,
      );
      final response = await client.send(request);

      abortTrigger.complete();

      expect(
        response.stream.single,
        throwsA(isA<RequestAbortedException>()),
      );
    });

    test('after response, response stream no listener', () async {
      final abortTrigger = Completer<void>();

      final request = AbortableRequest(
        'GET',
        serverUrl,
        abortTrigger: abortTrigger.future,
      );
      final response = await client.send(request);

      abortTrigger.complete();
      // Ensure that the abort has time to run before listening to the response
      // stream
      await Future<void>.delayed(const Duration());

      expect(
        response.stream.single,
        throwsA(isA<RequestAbortedException>()),
      );
    });

    test('after response, response stream paused', () async {
      final abortTrigger = Completer<void>();

      final request = AbortableRequest(
        'GET',
        serverUrl,
        abortTrigger: abortTrigger.future,
      );
      final response = await client.send(request);

      final subscription = response.stream.listen(print)..pause();
      abortTrigger.complete();
      // Ensure that the abort has time to run before listening to the response
      // stream
      await Future<void>.delayed(const Duration());
      subscription.resume();

      expect(
        subscription.asFuture<void>(),
        throwsA(isA<RequestAbortedException>()),
      );
    });

    test(
      'while streaming response',
      () async {
        final abortTrigger = Completer<void>();

        final request = AbortableRequest(
          'GET',
          serverUrl,
          abortTrigger: abortTrigger.future,
        );
        final response = await client.send(request);

        // Verify that fewer than the 10000 lines sent by the server are
        // received.
        var i = 0;
        await expectLater(
          response.stream
              .transform(const Utf8Decoder())
              .transform(const LineSplitter())
              .listen(
            (_) {
              if (++i >= 1000 && !abortTrigger.isCompleted) {
                abortTrigger.complete();
              }
            },
          ).asFuture<void>(),
          throwsA(isA<RequestAbortedException>()),
        );
        expect(i, lessThan(10000));
      },
      skip: supportsAbort
          ? (canStreamResponseBody ? false : 'does not stream response bodies')
          : 'does not support aborting requests',
    );

    test('after streaming response', () async {
      final abortTrigger = Completer<void>();

      final request = AbortableRequest(
        'GET',
        serverUrl,
        abortTrigger: abortTrigger.future,
      );

      final response = await client.send(request);
      await response.stream.drain<void>();

      abortTrigger.complete();
    });

    test('after response, client still useable', () async {
      final abortTrigger = Completer<void>();

      final request = AbortableRequest(
        'GET',
        serverUrl,
        abortTrigger: abortTrigger.future,
      );

      final abortResponse = await client.send(request);

      abortTrigger.complete();

      var requestAbortCaught = false;
      try {
        await abortResponse.stream.drain<void>();
      } on RequestAbortedException {
        requestAbortCaught = true;
      }

      final response = await client.get(serverUrl);
      expect(response.statusCode, 200);
      expect(response.body, endsWith('9999\n'));
      expect(requestAbortCaught, true);
    });
  }, skip: supportsAbort ? false : 'does not support aborting requests');
}
