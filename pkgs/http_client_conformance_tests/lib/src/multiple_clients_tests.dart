// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'multiple_clients_server_vm.dart'
    if (dart.library.html) 'multiple_clients_server_web.dart';

/// Tests that the [Client] works correctly if there are many used
/// simultaneously.
void testMultipleClients(Client Function() clientFactory) async {
  group('test multiple clients', () {
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('multiple clients with simultaneous requests', () async {
      final responseFutures = <Future<Response>>[];
      for (var i = 0; i < 5; ++i) {
        final client = clientFactory();
        responseFutures.add(client.get(Uri.http(host, '/$i')));
      }
      final responses = await Future.wait(responseFutures);
      for (var i = 0; i < 5; ++i) {
        expect(responses[i].statusCode, 200);
        expect(responses[i].body, i.toString());
      }
    });
  });
}
