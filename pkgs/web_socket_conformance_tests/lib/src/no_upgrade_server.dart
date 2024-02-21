// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'package:stream_channel/stream_channel.dart';

/// Starts an WebSocket server that closes the HTTP connection before WebSocket
/// upgrade.
void hybridMain(StreamChannel<Object?> channel) async {
  final server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      request.response.statusCode = 200;
      await request.response.close();
    });
  channel.sink.add(server.port);

  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close());
}
