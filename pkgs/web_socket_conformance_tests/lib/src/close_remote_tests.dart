// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

import 'close_remote_server_vm.dart'
    if (dart.library.html) 'close_remote_server_web.dart';

/// Tests that the [WebSocket] can correctly receive Close frames from the peer.
void testCloseRemote(
    Future<WebSocket> Function(Uri uri, {Iterable<String>? protocols})
        channelFactory) {
  group('remote close', () {
    late Uri uri;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      uri = Uri.parse('ws://localhost:${await httpServerQueue.next}');
    });
    tearDown(() async {
      httpServerChannel.sink.add(null);
    });

    test('with code and reason', () async {
      final channel = await channelFactory(uri);

      channel.sendText('Please close');
      expect(await channel.events.toList(),
          [CloseReceived(4123, 'server closed the connection')]);
    });

    test('sendBytes after close received', () async {
      final channel = await channelFactory(uri);

      channel.sendBytes(Uint8List(10));
      expect(await channel.events.toList(),
          [CloseReceived(4123, 'server closed the connection')]);
      expect(() => channel.sendText('test'),
          throwsA(isA<WebSocketConnectionClosed>()));
    });

    test('sendText after close received', () async {
      final channel = await channelFactory(uri);

      channel.sendText('Please close');
      expect(await channel.events.toList(),
          [CloseReceived(4123, 'server closed the connection')]);
      expect(() => channel.sendText('test'),
          throwsA(isA<WebSocketConnectionClosed>()));
    });

    test('close after close received', () async {
      final channel = await channelFactory(uri);

      channel.sendText('Please close');
      expect(await channel.events.toList(),
          [CloseReceived(4123, 'server closed the connection')]);
      await expectLater(
          channel.close, throwsA(isA<WebSocketConnectionClosed>()));
    });
  });
}
