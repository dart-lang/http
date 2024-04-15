// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

import 'no_upgrade_server_vm.dart'
    if (dart.library.html) 'no_upgrade_server_web.dart';

/// Tests that the [WebSocket] generates the correct exception if the peer
/// closes the HTTP connection before WebSocket upgrade.
void testNoUpgrade(
    Future<WebSocket> Function(Uri uri, {Iterable<String>? protocols})
        channelFactory) {
  group('no upgrade', () {
    late final Uri uri;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      uri = Uri.parse('ws://localhost:${await httpServerQueue.next}');
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('close before upgrade', () async {
      await expectLater(
          () => channelFactory(uri), throwsA(isA<WebSocketException>()));
    });
  });
}
