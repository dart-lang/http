// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'response_body_server_vm.dart'
    if (dart.library.js_interop) 'response_body_server_web.dart';

/// Tests that the [Client] correctly implements HTTP responses with bodies.
///
/// If [canStreamResponseBody] is `false` then tests that assume that the
/// [Client] supports receiving HTTP responses with unbounded body sizes will
/// be skipped
void testResponseBody(Client client,
    {bool canStreamResponseBody = true}) async {
  group('response body', () {
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;
    const message = 'Hello World!';

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('small response with content length', () async {
      final response = await client.get(Uri.http(host, ''));
      expect(response.body, message);
      expect(response.bodyBytes, message.codeUnits);
      expect(response.contentLength, message.length);
      expect(response.headers['content-type'], 'text/plain');
      expect(response.isRedirect, isFalse);
      expect(response.reasonPhrase, 'OK');
      expect(response.request!.method, 'GET');
      expect(response.statusCode, 200);
    });

    test('small response streamed without content length', () async {
      final request = Request('GET', Uri.http(host, ''));
      final response = await client.send(request);
      expect(await response.stream.bytesToString(), message);
      if (canStreamResponseBody) {
        expect(response.contentLength, null);
      } else {
        // If the response body is small then the Client can emulate a streamed
        // response without streaming. But `response.contentLength` may or
        // may not be set.
        expect(response.contentLength, isIn([null, 12]));
      }
      expect(response.headers['content-type'], 'text/plain');
      expect(response.isRedirect, isFalse);
      expect(response.reasonPhrase, 'OK');
      expect(response.request!.method, 'GET');
      expect(response.statusCode, 200);
    });

    test('small response streamed with content length', () async {
      final request = Request('GET', Uri.http(host, 'length'));
      final response = await client.send(request);
      expect(await response.stream.bytesToString(), message);
      expect(response.contentLength, 12);
      expect(response.headers['content-type'], 'text/plain');
      expect(response.isRedirect, isFalse);
      expect(response.reasonPhrase, 'OK');
      expect(response.request!.method, 'GET');
      expect(response.statusCode, 200);
    });
  });
}
