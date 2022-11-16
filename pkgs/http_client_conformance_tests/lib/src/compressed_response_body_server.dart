// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
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
      const message = 'Hello World!';
      final contents = gzip.encode(message.codeUnits);

      await request.drain<void>();

      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Content-Type', 'text/plain');
      request.response.headers.set('Content-Encoding', 'gzip');
      if (request.requestedUri.pathSegments.isNotEmpty &&
          request.requestedUri.pathSegments.last == 'length') {
        request.response.contentLength = contents.length;
      }
      request.response.add(contents);
      await request.response.close();
    });

  channel.sink.add(server.port);
  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close());
}
