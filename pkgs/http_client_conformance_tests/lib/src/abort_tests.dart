// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
  bool supportsAbort = true,
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
      final request = Request('GET', serverUrl);

      // TODO: Trigger abort

      expect(
          client.send(request),
          throwsA(
              isA<ClientException>().having((e) => e.uri, 'uri', serverUrl)));
    });

    test('during request stream', () async {
      final request = StreamedRequest('POST', serverUrl);

      final response = client.send(request);
      request.sink.add('Hello World'.codeUnits);
      // TODO: Trigger abort

      expect(
          response,
          throwsA(
              isA<ClientException>().having((e) => e.uri, 'uri', serverUrl)));
      await request
          .sink.done; // Verify that the stream subscription was cancelled.
    }, skip: canStreamRequestBody ? false : 'does not stream request bodies');

    test('after response', () async {
      final request = Request('GET', serverUrl);

      final response = await client.send(request);

      // TODO: Trigger abort

      expect(
          response.stream.single,
          throwsA(
              isA<ClientException>().having((e) => e.uri, 'uri', serverUrl)));
    });

    test('while streaming response', () async {
      final request = Request('GET', serverUrl);

      final response = await client.send(request);

      var i = 0;
      expect(
          response.stream.listen((data) {
            ++i;
            if (i == 1000) {
              // TODO: Trigger abort
            }
          }).asFuture<void>(),
          throwsA(
              isA<ClientException>().having((e) => e.uri, 'uri', serverUrl)));
      expect(i, 1000);
    });

    test('after streaming response', () async {
      final request = Request('GET', serverUrl);

      final response = await client.send(request);
      await response.stream.drain<void>();
      // Trigger abort, should have no effect.
    });
  });
}
