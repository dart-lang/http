// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';

/// Starts an HTTP server that returns custom headers.
///
/// Channel protocol:
///    On Startup:
///     - send port
///    On Request Received:
///     - load response header map from channel
///     - exit
void hybridMain(StreamChannel<Object?> channel) async {
  late HttpServer server;
  final clientQueue = StreamQueue(channel.stream);

  server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      await request.drain<void>();
      final socket = await request.response.detachSocket(writeHeaders: false);

      final headers = (await clientQueue.next) as String;
      socket
        ..writeAll([
          'HTTP/1.1 200 OK',
          'Access-Control-Allow-Origin: *',
          'Access-Control-Expose-Headers: *',
          'Content-Type: text/plain',
          '', // Add \r\n at the end of this header section.
        ], '\r\n')
        ..write(headers)
        ..write('Connection: Closed\r\n\r\n');
      await socket.close();
      unawaited(server.close());
    });

  channel.sink.add(server.port);
}
