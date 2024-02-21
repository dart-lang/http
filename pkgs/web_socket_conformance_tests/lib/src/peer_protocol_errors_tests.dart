// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

import 'peer_protocol_errors_server_vm.dart'
    if (dart.library.html) 'peer_protocol_errors_server_web.dart';

/// Tests that the [WebSocket] can correctly handle incorrect WebSocket frames.
void testPeerProtocolErrors(
    Future<WebSocket> Function(Uri uri, {Iterable<String>? protocols})
        channelFactory) {
  group('peer protocol errors', () {
    late final Uri uri;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      uri = Uri.parse('ws://localhost:${await httpServerQueue.next}');
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('bad data after upgrade', () async {
      final channel = await channelFactory(uri);
      expect(
          (await channel.events.single as CloseReceived).code,
          anyOf([
            1002, // protocol error
            1005, // closed no status
            1006, // closed abnormal
          ]));
    });

    test('bad data after upgrade with write', () async {
      final channel = await channelFactory(uri);
      channel.sendText('test');
      expect(
          (await channel.events.single as CloseReceived).code,
          anyOf([
            1002, // protocol error
            1005, // closed no status
            1006, // closed abnormal
          ]));
    });
  });
}
