// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

import 'echo_server_vm.dart' if (dart.library.html) 'echo_server_web.dart';

/// Tests that the [WebSocket] can correctly transmit and receive text
/// and binary payloads.
void testPayloadTransfer(
    Future<WebSocket> Function(Uri uri, {Iterable<String>? protocols})
        webSocketFactory) {
  group('payload transfer', () {
    late Uri uri;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;
    late WebSocket webSocket;

    setUp(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      uri = Uri.parse('ws://localhost:${await httpServerQueue.next}');
      webSocket = await webSocketFactory(uri);
    });
    tearDown(() async {
      httpServerChannel.sink.add(null);
      await webSocket.close();
    });

    test('empty string request and response', () async {
      webSocket.sendText('');
      expect(await webSocket.events.first, TextDataReceived(''));
    });

    test('empty binary request and response', () async {
      webSocket.sendBytes(Uint8List(0));
      expect(await webSocket.events.first, BinaryDataReceived(Uint8List(0)));
    });

    test('string request and response', () async {
      webSocket.sendText('Hello World!');
      expect(await webSocket.events.first, TextDataReceived('Hello World!'));
    });

    test('binary request and response', () async {
      webSocket.sendBytes(Uint8List.fromList([1, 2, 3, 4, 5]));
      expect(await webSocket.events.first,
          BinaryDataReceived(Uint8List.fromList([1, 2, 3, 4, 5])));
    });

    test('large string request and response', () async {
      final data = 'Hello World!' * 10000;

      webSocket.sendText(data);
      expect(await webSocket.events.first, TextDataReceived(data));
    });

    test('large binary request and response', () async {
      final data = Uint8List(1000000);
      data
        ..fillRange(0, data.length ~/ 10, 1)
        ..fillRange(0, data.length ~/ 10, 2)
        ..fillRange(0, data.length ~/ 10, 3)
        ..fillRange(0, data.length ~/ 10, 4)
        ..fillRange(0, data.length ~/ 10, 5)
        ..fillRange(0, data.length ~/ 10, 6)
        ..fillRange(0, data.length ~/ 10, 7)
        ..fillRange(0, data.length ~/ 10, 8)
        ..fillRange(0, data.length ~/ 10, 9)
        ..fillRange(0, data.length ~/ 10, 10);

      webSocket.sendBytes(data);
      expect(await webSocket.events.first, BinaryDataReceived(data));
    });

    test('non-ascii string request and response', () async {
      webSocket.sendText('🎨⛳🌈');
      expect(await webSocket.events.first, TextDataReceived('🎨⛳🌈'));
    });

    test('alternative string and binary request and response', () async {
      webSocket
        ..sendBytes(Uint8List.fromList([1]))
        ..sendText('Hello!')
        ..sendBytes(Uint8List.fromList([1, 2]))
        ..sendText('Hello World!');

      expect(await webSocket.events.take(4).toList(), [
        BinaryDataReceived(Uint8List.fromList([1])),
        TextDataReceived('Hello!'),
        BinaryDataReceived(Uint8List.fromList([1, 2])),
        TextDataReceived('Hello World!')
      ]);
    });
  });
}
