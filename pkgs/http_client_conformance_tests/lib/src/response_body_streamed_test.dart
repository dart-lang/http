// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

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
    }, skip: canStreamResponseBody ? false : 'does not stream response bodies');
  });
}
