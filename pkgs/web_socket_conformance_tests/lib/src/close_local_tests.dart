// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

import 'close_local_server_vm.dart'
    if (dart.library.html) 'close_server_web.dart';

/// Tests that the [WebSocketChannel] can correctly transmit and receive text
/// and binary payloads.
void testLocalClose(
    Future<WebSocket> Function(Uri uri, {Iterable<String>? protocols})
        channelFactory) {
  group('local close', () {
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
//      await httpServerQueue.next;
    });
/*
    test('connected', () async {
      final channel = channelFactory(uri);

      await expectLater(channel.ready, completes);
      expect(channel.closeCode, null);
      expect(channel.closeReason, null);
    });
*/
    // https://websockets.spec.whatwg.org/#eventdef-websocket-close
    // Dart will wait up to 5 seconds to get the close code from the server otherwise
    // it will use the local close code.

    test('reserved close code', () async {
      // If code is present, but is neither an integer equal to 1000 nor an integer in the range 3000 to 4999, inclusive, throw an "InvalidAccessError" DOMException.
      // If reasonBytes is longer than 123 bytes, then throw a "SyntaxError" DOMException.

      final channel = await channelFactory(uri);
      await expectLater(() => channel.close(1004), throwsA(isA<RangeError>()));
    });

    test('too long close reason', () async {
      final channel = await channelFactory(uri);
      await expectLater(() => channel.close(3000, 'a'.padLeft(124)),
          throwsA(isA<ArgumentError>()));
    });

    test('close', () async {
      final channel = await channelFactory(uri);

      await channel.close();
      final closeCode = await httpServerQueue.next as int?;
      final closeReason = await httpServerQueue.next as String?;

      expect(closeCode, 1005);
      expect(closeReason, '');
      expect(await channel.events.isEmpty, true);
    });

    test('with code 3000', () async {
      final channel = await channelFactory(uri);

      await channel.close(3000);
      final closeCode = await httpServerQueue.next as int?;
      final closeReason = await httpServerQueue.next as String?;

      expect(closeCode, 3000);
      expect(closeReason, '');
      expect(await channel.events.isEmpty, true);
    });

    test('with code 4999', () async {
      final channel = await channelFactory(uri);

      await channel.close(4999);
      final closeCode = await httpServerQueue.next as int?;
      final closeReason = await httpServerQueue.next as String?;

      expect(closeCode, 4999);
      expect(closeReason, '');
      expect(await channel.events.isEmpty, true);
    });

    test('with code and reason', () async {
      final channel = await channelFactory(uri);

      await channel.close(3000, 'Client initiated closure');
      final closeCode = await httpServerQueue.next as int?;
      final closeReason = await httpServerQueue.next as String?;

      expect(closeCode, 3000);
      expect(closeReason, 'Client initiated closure');
      expect(await channel.events.isEmpty, true);
    });

    test('close after close', () async {
      final channel = await channelFactory(uri);

      await channel.close(3000, 'Client initiated closure');

      expectLater(
          () async => await channel.close(3001, 'Client initiated closure'),
          throwsA(isA<WebSocketConnectionClosed>()));
      final closeCode = await httpServerQueue.next as int?;
      final closeReason = await httpServerQueue.next as String?;

      expect(closeCode, 3000);
      expect(closeReason, 'Client initiated closure');
      expect(await channel.events.isEmpty, true);
    });
  });
}
