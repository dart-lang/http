// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';

/// Starts an HTTP server that sends a stream of integers.
///
/// Channel protocol:
///    On Startup:
///     - send port
///    When Receive Anything:
///     - close current request
///     - exit server
void hybridMain(StreamChannel<Object?> channel) async {
  final channelQueue = StreamQueue(channel.stream);
  var serverWriting = true;

  late HttpServer server;
  server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      await request.drain<void>();
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Content-Type', 'text/plain');
      serverWriting = true;
      for (var i = 0; serverWriting; ++i) {
        request.response.write('$i\n');
        await request.response.flush();
        // Let the event loop run.
        await Future(() {});
      }
      await request.response.close();
      unawaited(server.close());
    });

  channel.sink.add(server.port);
  unawaited(channelQueue.next.then((value) => serverWriting = false));
}
