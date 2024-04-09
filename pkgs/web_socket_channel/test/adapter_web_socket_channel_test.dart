// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';
import 'package:web_socket_channel/adapter_web_socket_channel.dart';
import 'package:web_socket_channel/src/exception.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'echo_server_vm.dart'
    if (dart.library.js_interop) 'echo_server_web.dart';

void main() {
  group('AdapterWebSocketChannel', () {
    late Uri uri;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);

      // When run under dart2wasm, JSON numbers are always returned as [double].
      final port = ((await httpServerQueue.next) as num).toInt();
      uri = Uri.parse('ws://localhost:$port');
    });
    tearDown(() async {
      httpServerChannel.sink.add(null);
    });

    test('failed connect', () async {
      final channel =
          AdapterWebSocketChannel.connect(Uri.parse('ws://notahost'));

      await expectLater(
          channel.ready, throwsA(isA<WebSocketChannelException>()));
    });

    test('good connect', () async {
      final channel = AdapterWebSocketChannel.connect(uri);
      await expectLater(channel.ready, completes);
      await channel.sink.close();
    });

    test('echo empty text', () async {
      final channel = AdapterWebSocketChannel.connect(uri);
      await expectLater(channel.ready, completes);
      channel.sink.add('');
      expect(await channel.stream.first, '');
      await channel.sink.close();
    });

    test('echo empty binary', () async {
      final channel = AdapterWebSocketChannel.connect(uri);
      await expectLater(channel.ready, completes);
      channel.sink.add(Uint8List.fromList(<int>[]));
      expect(await channel.stream.first, isEmpty);
      await channel.sink.close();
    });

    test('echo hello', () async {
      final channel = AdapterWebSocketChannel.connect(uri);
      await expectLater(channel.ready, completes);
      channel.sink.add('hello');
      expect(await channel.stream.first, 'hello');
      await channel.sink.close();
    });

    test('echo [1,2,3]', () async {
      final channel = AdapterWebSocketChannel.connect(uri);
      await expectLater(channel.ready, completes);
      channel.sink.add([1, 2, 3]);
      expect(await channel.stream.first, [1, 2, 3]);
      await channel.sink.close();
    });

    test('alternative string and binary request and response', () async {
      final channel = AdapterWebSocketChannel.connect(uri);
      await expectLater(channel.ready, completes);
      channel.sink.add('This count says:');
      channel.sink.add([1, 2, 3]);
      channel.sink.add('And then:');
      channel.sink.add([4, 5, 6]);
      expect(await channel.stream.take(4).toList(), [
        'This count says:',
        [1, 2, 3],
        'And then:',
        [4, 5, 6]
      ]);
    });

    test('remote close', () async {
      final channel = AdapterWebSocketChannel.connect(uri);
      await expectLater(channel.ready, completes);
      channel.sink.add('close'); // Asks the peer to close.
      // Give the server time to send a close frame.
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(channel.closeCode, 3001);
      expect(channel.closeReason, 'you asked me to');
      await channel.sink.close();
    });

    test('local close', () async {
      final channel = AdapterWebSocketChannel.connect(uri);
      await expectLater(channel.ready, completes);
      await channel.sink.close(3005, 'please close');
      expect(channel.closeCode, null);
      expect(channel.closeReason, null);
    });

    test('constructor with WebSocket', () async {
      final webSocket = await WebSocket.connect(uri);
      final channel = AdapterWebSocketChannel(webSocket);

      await expectLater(channel.ready, completes);
      channel.sink.add('This count says:');
      channel.sink.add([1, 2, 3]);
      channel.sink.add('And then:');
      channel.sink.add([4, 5, 6]);
      expect(await channel.stream.take(4).toList(), [
        'This count says:',
        [1, 2, 3],
        'And then:',
        [4, 5, 6]
      ]);
    });

    test('constructor with Future<WebSocket>', () async {
      final webSocketFuture = WebSocket.connect(uri);
      final channel = AdapterWebSocketChannel(webSocketFuture);

      await expectLater(channel.ready, completes);
      channel.sink.add('This count says:');
      channel.sink.add([1, 2, 3]);
      channel.sink.add('And then:');
      channel.sink.add([4, 5, 6]);
      expect(await channel.stream.take(4).toList(), [
        'This count says:',
        [1, 2, 3],
        'And then:',
        [4, 5, 6]
      ]);
    });
  });
}
