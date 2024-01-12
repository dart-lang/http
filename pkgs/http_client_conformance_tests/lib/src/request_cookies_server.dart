// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

/// Starts an HTTP server that captures "cookie" headers.
///
/// Channel protocol:
///    On Startup:
///     - send port
///    On Request Received:
///     - send a list of header lines starting with "cookie:"
///    When Receive Anything:
///     - exit
void hybridMain(StreamChannel<Object?> channel) async {
  late ServerSocket server;

  server = (await ServerSocket.bind('localhost', 0))
    ..listen((Socket socket) async {
      final request = utf8.decoder.bind(socket).transform(const LineSplitter());

      final cookies = <String>[];
      request.listen((line) {
        if (line.toLowerCase().startsWith('cookie:')) {
          cookies.add(line);
        }

        if (line.isEmpty) {
          // A blank line indicates the end of the headers.
          channel.sink.add(cookies);
        }
      });

      socket.writeAll(
        [
          'HTTP/1.1 200 OK',
          'Access-Control-Allow-Origin: *',
          'Content-Length: 0',
          '\r\n', // Add \r\n at the end of this header section.
        ],
        '\r\n', // Separate each field by \r\n.
      );
      await socket.close();
    });

  channel.sink.add(server.port);
  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close());
}
