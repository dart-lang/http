// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:isolate' if (dart.library.html) 'dummy_isolate.dart';

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'request_body_server_vm.dart'
    if (dart.library.html) 'request_body_server_web.dart';

Future<void> _testPost(Client Function() clientFactory, String host) async {
  await Isolate.run(
      () => clientFactory().post(Uri.http(host, ''), body: 'Hello World!'));
}

/// Tests that the [Client] is useable from Isolates other than the main
/// isolate.
///
/// If [canWorkInIsolates] is `false` then the tests will be skipped.
void testIsolate(Client Function() clientFactory,
    {bool canWorkInIsolates = true}) {
  group('test isolate', () {
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('client.post() with string body', () async {
      await _testPost(clientFactory, host);

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next;

      expect(serverReceivedContentType, ['text/plain; charset=utf-8']);
      expect(serverReceivedBody, 'Hello World!');
    });
  },
      skip: canWorkInIsolates
          ? false
          : 'does not work outside of the main isolate');
}
