// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:websocket/websocket.dart';

import 'close_remote_server_vm.dart'
    if (dart.library.html) 'close_remote_server_web.dart';

/// Tests that the [WebSocketChannel] can correctly transmit and receive text
/// and binary payloads.
void testRemoteClose(
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

/*
    test('reserved close code', () async {
      // If code is present, but is neither an integer equal to 1000 nor an integer in the range 3000 to 4999, inclusive, throw an "InvalidAccessError" DOMException.
      // If reasonBytes is longer than 123 bytes, then throw a "SyntaxError" DOMException.

      final channel = channelFactory(uri);

      await expectLater(channel.ready, completes);
      expect(channel.closeCode, null);
      expect(channel.closeReason, null);
      // web uncaught // InvalidAccessError
      // sync WebSocketException
      await channel.sink.close(1004, 'boom');
    });

    test('too long close reason', () async {
      final channel = channelFactory(uri);

      await expectLater(channel.ready, completes);
      expect(channel.closeCode, null);
      expect(channel.closeReason, null);
      // web uncaught // SyntaxError
      // vm: passes!
      await channel.sink.close(1000, 'Boom'.padLeft(1000));
    });
*/
    test('with code and reason', () async {
      final channel = await channelFactory(uri);

      channel.addString('Please close');
      expect(await channel.events.toList(),
          [Closed(4123, 'server closed the connection')]);
    });

    test('send after close', () async {
      final channel = await channelFactory(uri);

      channel.addString('Please close');
      expect(await channel.events.toList(),
          [Closed(4123, 'server closed the connection')]);
      expect(() => channel.addString('test'), throwsStateError);

      print(await httpServerQueue.next);
      print(await httpServerQueue.next);

/*
      final closeCode = await httpServerQueue.next as int?;
      final closeReason = await httpServerQueue.next as String?;
      expect(closeCode, 3000);
      expect(closeReason, 'Client initiated closure');*/
    });
/*
    test('cancel', () async {
      final channel =
          channelFactory(uri.replace(queryParameters: {'sleep': '5'}));

      var sinkDoneComplete = false;
      var sinkDoneOnError = false;
      var streamOnData = false;
      var streamOnDone = false;
      var streamOnError = false;

      channel.sink.done.then((_) {
        sinkDoneComplete = true;
      }, onError: (_) {
        sinkDoneOnError = true;
      });

      final streamSubscription = channel.stream.listen((_) {
        streamOnData = true;
      }, onError: (_) {
        streamOnError = true;
      }, onDone: () {
        streamOnDone = true;
      });

      await expectLater(channel.ready, completes);
      // VM: Cancels subscription to the socket, which means that this deadlocks.
      await streamSubscription.cancel();
      expect(() => channel.stream.listen((_) {}), throwsStateError);
      channel.sink.add('add after stream closed');

      expect(channel.closeCode, null);
      expect(channel.closeReason, null);

      expect(sinkDoneComplete, false);
      expect(sinkDoneOnError, false);
      expect(streamOnData, false);
      expect(streamOnDone, false);
      expect(streamOnError, false);

      await channel.sink.done;
      expect(await httpServerQueue.next, 'add after stream closed');
      expect(await httpServerQueue.next, null);
      expect(await httpServerQueue.next, null);
      expect(channel.closeCode, 4123);
      expect(channel.closeReason, 'server closed the connection');
      // cancelling should close according to lassa!
    }, skip: _isVM);

    test('cancel - client close', () async {
      final channel =
          channelFactory(uri.replace(queryParameters: {'sleep': '5'}));

      var sinkDoneComplete = false;
      var sinkDoneOnError = false;
      var streamOnData = false;
      var streamOnDone = false;
      var streamOnError = false;

      channel.sink.done.then((_) {
        sinkDoneComplete = true;
      }, onError: (_) {
        sinkDoneOnError = true;
      });

      final streamSubscription = channel.stream.listen((_) {
        streamOnData = true;
      }, onError: (_) {
        streamOnError = true;
      }, onDone: () {
        streamOnDone = true;
      });

      await expectLater(channel.ready, completes);
      await streamSubscription.cancel();
      expect(() => channel.stream.listen((_) {}), throwsStateError);
      channel.sink.add('add after stream closed');

      expect(channel.closeCode, null);
      expect(channel.closeReason, null);

      expect(sinkDoneComplete, false);
      expect(sinkDoneOnError, false);
      expect(streamOnData, false);
      expect(streamOnDone, false);
      expect(streamOnError, false);

      await channel.sink.close(4444, 'client closed the connection');
      expect(await httpServerQueue.next, 'add after stream closed');
      expect(await httpServerQueue.next, 4444);
      expect(await httpServerQueue.next, 'client closed the connection');
      expect(channel.closeCode, 4444);
      expect(channel.closeReason, 'client closed the connection');
    });

    test('client initiated', () async {
      final channel = channelFactory(uri);

      var sinkDoneComplete = false;
      var sinkDoneOnError = false;
      var streamOnData = false;
      var streamOnDone = false;
      var streamOnError = false;

      channel.sink.done.then((_) {
        sinkDoneComplete = true;
      }, onError: (_) {
        sinkDoneOnError = true;
      });

      channel.stream.listen((_) {
        streamOnData = true;
      }, onError: (_) {
        streamOnError = true;
      }, onDone: () {
        streamOnDone = true;
      });

      await expectLater(channel.ready, completes);
      await channel.sink.close(4444, 'client closed the connection');
      expect(channel.closeCode, null); // VM 4123
      expect(channel.closeReason, null); // VM 'server closed the connection'

      expect(await httpServerQueue.next, 4444); // VM 4123
      expect(await httpServerQueue.next,
          'client closed the connection'); // VM 'server closed the connection'
      expect(channel.closeCode, 4123);
      expect(channel.closeReason, 'server closed the connection');
      expect(() => channel.sink.add('add after connection closed'),
          throwsStateError);

      expect(sinkDoneComplete, true);
      expect(sinkDoneOnError, false);
      expect(streamOnData, false);
      expect(streamOnDone, true);
      expect(streamOnError, false);
    }, skip: _isVM);

    test('client initiated - slow server', () async {
      final channel =
          channelFactory(uri.replace(queryParameters: {'sleep': '5'}));

      var sinkDoneComplete = false;
      var sinkDoneOnError = false;
      var streamOnData = false;
      var streamOnDone = false;
      var streamOnError = false;

      channel.sink.done.then((_) {
        sinkDoneComplete = true;
      }, onError: (_) {
        sinkDoneOnError = true;
      });

      channel.stream.listen((_) {
        streamOnData = true;
      }, onError: (_) {
        streamOnError = true;
      }, onDone: () {
        streamOnDone = true;
      });

      await expectLater(channel.ready, completes);
      await channel.sink.close(4444, 'client closed the connection');
      expect(channel.closeCode, null);
      expect(channel.closeReason, null);

      expect(await httpServerQueue.next, 4444);
      expect(await httpServerQueue.next, 'client closed the connection');
      expect(channel.closeCode, 4444); // VM: null - sometimes null
      expect(channel.closeReason, 'client closed the connection'); // VM: null
      expect(() => channel.sink.add('add after connection closed'),
          throwsStateError);
      await channel.sink.close();

      expect(sinkDoneComplete, true);
      expect(sinkDoneOnError, false);
      expect(streamOnData, false);
      expect(streamOnDone, true);
      expect(streamOnError, false);
    });

    test('server initiated', () async {
      final channel = channelFactory(uri);

      var sinkDoneComplete = false;
      var sinkDoneOnError = false;
      var streamOnData = false;
      var streamOnDone = false;
      var streamOnError = false;

      channel.sink.done.then((_) {
        sinkDoneComplete = true;
      }, onError: (_) {
        sinkDoneOnError = true;
      });

      final streamListen = channel.stream.listen((_) {
        streamOnData = true;
      }, onError: (_) {
        streamOnError = true;
      }).asFuture<void>();

      await expectLater(channel.ready, completes);
      await streamListen;

      expect(channel.closeCode, 4123);
      expect(channel.closeReason, 'server closed the connection');
      channel.sink.add('add after connection closed');
      await channel.sink.close();

      expect(sinkDoneComplete, true);
      expect(sinkDoneOnError, false);
      expect(streamOnData, false);
      expect(streamOnError, false);
    });
    */
  });
}
