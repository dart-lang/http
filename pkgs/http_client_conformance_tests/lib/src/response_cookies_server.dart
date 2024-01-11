// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';

/// Starts an HTTP server that returns a custom status line.
///
/// Channel protocol:
///    On Startup:
///     - send port
///    On Request Received:
///     - load response status line from channel
///     - exit
void hybridMain(StreamChannel<Object?> channel) async {
  late HttpServer server;
  final clientQueue = StreamQueue(channel.stream);

  server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      await request.drain<void>();
      final socket = await request.response.detachSocket(writeHeaders: false);

      final headers = (await clientQueue.next) as List;
      socket.writeAll(
        [
          'HTTP/1.1 200 OK',
          'Access-Control-Allow-Origin: *',
          'Content-Length: 0',
          ...headers,
          '\r\n', // Add \r\n at the end of this header section.
        ],
        '\r\n', // Separate each field by \r\n.
      );
      await socket.close();
      unawaited(server.close());
    });

  channel.sink.add(server.port);
}
