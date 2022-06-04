// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

/// Starts an HTTP server that responds with "Hello World!"
///
/// Channel protocol:
///    On Startup:
///     - send port
///    When Receive Anything:
///     - exit
void hybridMain(StreamChannel<Object?> channel) async {
  final server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      await request.drain<void>();
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Content-Type', 'text/plain');
      request.response.write('Hello World!');
      await request.response.close();
    });

  channel.sink.add(server.port);
  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close());
}
