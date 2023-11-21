// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'request_body_streamed_server_vm.dart'
    if (dart.library.js_interop) 'request_body_streamed_server_web.dart';

/// Tests that the [Client] correctly implements streamed request body
/// uploading.
///
/// If [canStreamRequestBody] is `false` then tests that assume that the
/// [Client] supports sending HTTP requests with unbounded body sizes will be
/// skipped.
void testRequestBodyStreamed(Client client,
    {bool canStreamRequestBody = true}) {
  group('streamed requests', () {
    late String host;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });
    tearDown(() => httpServerChannel.sink.add(null));

    test('client.send() with StreamedRequest', () async {
      // The client continuously streams data to the server until
      // instructed to stop (by setting `clientWriting` to `false`).
      // The server sets `serverWriting` to `false` after it has
      // already received some data.
      //
      // This ensures that the client supports streamed data sends.
      var lastReceived = 0;

      Stream<String> count() async* {
        var i = 0;
        unawaited(
            httpServerQueue.next.then((value) => lastReceived = value as int));
        do {
          yield '${i++}\n';
          // Let the event loop run.
          await Future<void>.delayed(const Duration());
        } while (lastReceived < 1000);
      }

      final request = StreamedRequest('POST', Uri.http(host, ''));
      const Utf8Encoder().bind(count()).listen(request.sink.add,
          onError: request.sink.addError, onDone: request.sink.close);
      await client.send(request);

      expect(lastReceived, greaterThanOrEqualTo(1000));
    });
  }, skip: canStreamRequestBody ? false : 'does not stream request bodies');
}
