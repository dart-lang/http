// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'request_body_server_vm.dart'
    if (dart.library.html) 'request_body_server_web.dart';

/// Tests that the [Client] correctly implements [Client.close].
void testClose(Client Function() clientFactory) {
  group('close', () {
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('close no request', () async {
      clientFactory().close();
    });

    test('close after request', () async {
      final client = clientFactory();
      await client.post(Uri.http(host, ''), body: 'Hello');
      client.close();
    });

    test('multiple close after request', () async {
      final client = clientFactory();
      await client.post(Uri.http(host, ''), body: 'Hello');
      client
        ..close()
        ..close();
    });

    test('request after close', () async {
      final client = clientFactory();
      await client.post(Uri.http(host, ''), body: 'Hello');
      client.close();
      expect(() async => await client.post(Uri.http(host, ''), body: 'Hello'),
          throwsA(isA<ClientException>()));
    });
  });
}
