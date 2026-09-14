// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'bodyless_request_server_vm.dart'
    if (dart.library.js_interop) 'bodyless_request_server_web.dart';

/// Tests that the [Client] correctly sends bodyless requests without framing
/// headers (`Content-Length` or `Transfer-Encoding`) and without transferring
/// body bytes on the wire.
///
/// RFC-9110 8.6 says:
/// > A user agent SHOULD NOT send a Content-Length header field when the
/// > request message does not contain content and the method semantics do not
/// > anticipate such data.
///
/// RFC-9110 9.3.1 says:
/// > A client SHOULD NOT generate content in a GET request unless it is made
/// > directly to an origin server that has previously indicated, in or out of
/// > band, that such a request has a purpose and will be adequately supported.
void testBodylessRequests(Client Function() clientFactory) {
  group('bodyless requests', () {
    late Client client;
    late String host;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      client = clientFactory();
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.nextAsInt}';
    });
    tearDown(() {
      client.close();
      httpServerChannel.sink.add(null);
    });

    test('client.send() with bodyless StreamedRequest GET', () async {
      final request = StreamedRequest('GET', Uri.http(host, ''));
      unawaited(request.sink.close());
      final response = await client.send(request);
      await response.stream.drain<void>();

      final serverReceived = await httpServerQueue.next as Map;
      final headers =
          (serverReceived['headers'] as Map).cast<String, List<Object?>>();
      final body = (serverReceived['body'] as List).cast<int>();

      expect(headers.containsKey('transfer-encoding'), isFalse);
      expect(headers.containsKey('content-length'), isFalse);
      expect(body, isEmpty);
    });

    test('client.send() with bodyless StreamedRequest HEAD', () async {
      final request = StreamedRequest('HEAD', Uri.http(host, ''));
      unawaited(request.sink.close());
      final response = await client.send(request);
      await response.stream.drain<void>();

      final serverReceived = await httpServerQueue.next as Map;
      final headers =
          (serverReceived['headers'] as Map).cast<String, List<Object?>>();
      final body = (serverReceived['body'] as List).cast<int>();

      expect(headers.containsKey('transfer-encoding'), isFalse);
      expect(headers.containsKey('content-length'), isFalse);
      expect(body, isEmpty);
    });
  });
}
