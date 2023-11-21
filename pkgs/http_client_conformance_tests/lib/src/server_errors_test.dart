// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'server_errors_server_vm.dart'
    if (dart.library.js_interop) 'server_errors_server_web.dart';

/// Tests that the [Client] correctly handles server errors.
void testServerErrors(Client client, {bool redirectAlwaysAllowed = false}) {
  group('server errors', () {
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('no such host', () async {
      expect(
          client.get(Uri.http('thisisnotahost', '')),
          throwsA(isA<ClientException>()
              .having((e) => e.uri, 'uri', Uri.http('thisisnotahost', ''))));
    });

    test('disconnect', () async {
      expect(
          client.get(Uri.http(host, '')),
          throwsA(isA<ClientException>()
              .having((e) => e.uri, 'uri', Uri.http(host, ''))));
    });
  });
}
