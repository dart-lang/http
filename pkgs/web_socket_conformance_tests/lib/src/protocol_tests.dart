// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

import 'protocol_server_vm.dart'
    if (dart.library.html) 'protocol_server_web.dart';

/// Tests that the [WebSocket] can correctly negotiate a subprotocol with the
/// peer.
///
/// See
/// [RFC-6455 1.9](https://datatracker.ietf.org/doc/html/rfc6455#section-1.9).
void testProtocols(
    Future<WebSocket> Function(Uri uri, {Iterable<String>? protocols})
        channelFactory) {
  group('protocols', () {
    late Uri uri;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      uri = Uri.parse('ws://localhost:${await httpServerQueue.next}');
    });
    tearDown(() => httpServerChannel.sink.add(null));

    test('no protocol', () async {
      final socket = await channelFactory(uri);

      expect(await httpServerQueue.next, null);
      expect(socket.protocol, '');
      socket.sendText('Hello World!');
    });

    test('single protocol', () async {
      final socket = await channelFactory(
          uri.replace(queryParameters: {'protocol': 'chat.example.com'}),
          protocols: ['chat.example.com']);

      expect(await httpServerQueue.next, ['chat.example.com']);
      expect(socket.protocol, 'chat.example.com');
      socket.sendText('Hello World!');
    });

    test('mutiple protocols', () async {
      final socket = await channelFactory(
          uri.replace(queryParameters: {'protocol': 'text.example.com'}),
          protocols: ['chat.example.com', 'text.example.com']);

      expect(
          await httpServerQueue.next, ['chat.example.com, text.example.com']);
      expect(socket.protocol, 'text.example.com');
      socket.sendText('Hello World!');
    });

    test('protocol mismatch', () async {
      await expectLater(
          () => channelFactory(
              uri.replace(queryParameters: {'protocol': 'example.example.com'}),
              protocols: ['chat.example.com']),
          throwsA(isA<WebSocketException>()));
    });
  });
}
