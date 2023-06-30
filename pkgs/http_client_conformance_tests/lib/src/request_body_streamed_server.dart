// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

/// Starts an HTTP server that absorbs a request stream of integers and
/// signals the client to quit after 1000 have been received.
///
/// Channel protocol:
///    On Startup:
///     - send port
///    On Integer == 1000 received:
///     - send 1000
///    When Receive Anything:
///     - exit
void hybridMain(StreamChannel<Object?> channel) async {
  late HttpServer server;

  server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      await const LineSplitter()
          .bind(const Utf8Decoder().bind(request))
          .forEach((s) {
        final lastReceived = int.parse(s.trim());
        if (lastReceived == 1000) {
          channel.sink.add(lastReceived);
        }
      });
      unawaited(request.response.close());
    });

  channel.sink.add(server.port);
  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close());
}
