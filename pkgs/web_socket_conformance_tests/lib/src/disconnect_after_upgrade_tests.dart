// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:websocket/websocket.dart';

import 'disconnect_after_upgrade_server_vm.dart'
    if (dart.library.html) 'disconnect_after_upgrade_server_web.dart';

/// Tests that the [WebSocketChannel] can correctly transmit and receive text
/// and binary payloads.
void testDisconnectAfterUpgrade(
    Future<XXXWebSocket> Function(Uri uri, {Iterable<String>? protocols})
        channelFactory) {
  group('disconnect', () {
    late final Uri uri;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      uri = Uri.parse('ws://localhost:${await httpServerQueue.next}');
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('disconnect after upgrade', () async {
      final channel = await channelFactory(uri);
      channel.addString('test');
      expect(
          (await channel.events.single as Closed).code,
          anyOf([
            1005, // closed no status
            1006, // closed abnormal
          ]));
    });
  });
}
