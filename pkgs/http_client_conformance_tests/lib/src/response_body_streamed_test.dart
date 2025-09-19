// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'response_body_streamed_server_vm.dart'
    if (dart.library.js_interop) 'response_body_streamed_server_web.dart';

/// Tests that the [Client] correctly implements HTTP responses with bodies of
/// unbounded size.
///
/// If [canStreamResponseBody] is `false` then tests that assume that the
/// [Client] supports receiving HTTP responses with unbounded body sizes will
/// be skipped
void testResponseBodyStreamed(Client client,
    {bool canStreamResponseBody = true}) async {
  group('streamed response body', () {
    late String host;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.nextAsInt}';
    });
    tearDown(() => httpServerChannel.sink.add(null));

    test('large response streamed without content length', () async {
      // The server continuously streams data to the client until
      // instructed to stop.
      //
      // This ensures that the client supports streamed responses.

      final request = Request('GET', Uri.http(host, ''));
      final response = await client.send(request);
      expect(response.contentLength, null);
      var lastReceived = 0;
      await const LineSplitter()
          .bind(const Utf8Decoder().bind(response.stream))
          .forEach((s) {
        lastReceived = int.parse(s.trim());
        if (lastReceived == 1000) {
          httpServerChannel.sink.add(true);
        }
      });
      expect(response.headers['content-type'], 'text/plain');
      expect(lastReceived, greaterThanOrEqualTo(1000));
      expect(response.isRedirect, isFalse);
      expect(response.reasonPhrase, 'OK');
      expect(response.request!.method, 'GET');
      expect(response.statusCode, 200);
    });

    test('cancel streamed response', () async {
      final request = Request('GET', Uri.http(host, ''));
      final response = await client.send(request);
      final cancelled = Completer<void>();
      expect(response.reasonPhrase, 'OK');
      expect(response.statusCode, 200);
      late StreamSubscription<String> subscription;
      subscription = const LineSplitter()
          .bind(const Utf8Decoder().bind(response.stream))
          .listen((s) async {
        final lastReceived = int.parse(s.trim());
        if (lastReceived == 1000) {
          unawaited(subscription.cancel());
          cancelled.complete();
        }
      });
      await cancelled.future;
    });

    test('cancelling stream subscription after chunk', () async {
      // Request a 10s delay between subsequent lines.
      const delayMillis = 10000;
      final request = Request('GET', Uri.http(host, '$delayMillis'));
      final response = await client.send(request);
      expect(response.reasonPhrase, 'OK');
      expect(response.statusCode, 200);

      var stopwatch = Stopwatch()..start();
      var line = await const LineSplitter()
          .bind(const Utf8Decoder().bind(response.stream))
          // Cancel the stream after the first line
          .first;

      // Receiving the first line and cancelling the stream should not wait for
      // the second line, which is sent much later.
      stopwatch.stop();
      expect(line, '0');
      expect(stopwatch.elapsed.inMilliseconds, lessThan(delayMillis));
    });

    test('cancelling stream subscription after chunk with delay', () async {
      // Request a 10s delay between subsequent lines.
      const delayMillis = 10000;
      final request = Request('GET', Uri.http(host, '$delayMillis'));
      final response = await client.send(request);
      expect(response.reasonPhrase, 'OK');
      expect(response.statusCode, 200);

      var stopwatch = Stopwatch()..start();
      final done = Completer<void>();
      late StreamSubscription<String> sub;
      sub = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) async {
        // Don't cancel in direct response to event, we want to test cancelling
        // while the client is actively waiting for data.
        await pumpEventQueue();
        await sub.cancel();
        stopwatch.stop();
        done.complete();
      });

      await done.future;
      // Receiving the first line and cancelling the stream should not wait for
      // the second line, which is sent much later.
      expect(stopwatch.elapsed.inMilliseconds, lessThan(delayMillis));
    });
  }, skip: canStreamResponseBody ? false : 'does not stream response bodies');
}
