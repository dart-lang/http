// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

import 'close_local_server_vm.dart'
    if (dart.library.html) 'close_local_server_web.dart';

import 'continuously_writing_server_vm.dart'
    if (dart.library.html) 'continuously_writing_server_web.dart'
    as writing_server;

/// Tests that the [WebSocket] can correctly close the connection to the peer.
void testCloseLocal(
    Future<WebSocket> Function(Uri uri, {Iterable<String>? protocols})
        channelFactory) {
  group('remote writing', () {
    late Uri uri;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel = await writing_server.startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      uri = Uri.parse('ws://localhost:${await httpServerQueue.next}');
    });
    tearDown(() async {
      httpServerChannel.sink.add(null);
    });

    test('peer writes after close are ignored', () async {
      final channel = await channelFactory(uri);
      await channel.close();
      expect(await channel.events.isEmpty, true);
    });
  });

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
    });

    test('reserved close code: 1004', () async {
      final channel = await channelFactory(uri);
      await expectLater(
          () => channel.close(1004), throwsA(isA<ArgumentError>()));
    });

    test('reserved close code: 2999', () async {
      final channel = await channelFactory(uri);
      await expectLater(
          () => channel.close(2999), throwsA(isA<ArgumentError>()));
    });

    test('reserved close code: 5000', () async {
      final channel = await channelFactory(uri);
      await expectLater(
          () => channel.close(5000), throwsA(isA<ArgumentError>()));
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

    test('close with 1000', () async {
      final channel = await channelFactory(uri);

      await channel.close(1000);
      final closeCode = await httpServerQueue.next as int?;
      final closeReason = await httpServerQueue.next as String?;

      expect(closeCode, 1000);
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

      await expectLater(
          () async => await channel.close(3001, 'Client initiated closure'),
          throwsA(isA<WebSocketConnectionClosed>()));
    });

    test('sendBytes after close', () async {
      final channel = await channelFactory(uri);

      await channel.close(3000, 'Client initiated closure');

      expect(() => channel.sendBytes(Uint8List(10)),
          throwsA(isA<WebSocketConnectionClosed>()));
    });

    test('sendText after close', () async {
      final channel = await channelFactory(uri);

      await channel.close(3000, 'Client initiated closure');

      expect(() => channel.sendText('Hello World'),
          throwsA(isA<WebSocketConnectionClosed>()));
    });
  });
}
