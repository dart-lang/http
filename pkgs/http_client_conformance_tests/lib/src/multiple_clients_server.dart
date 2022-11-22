// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

/// Starts an HTTP server that responds the client request path.
///
/// Channel protocol:
///    On Startup:
///     - send port
///    When Receive Anything:
///     - exit
void hybridMain(StreamChannel<Object?> channel) async {
  final server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      request.response.headers.set('Access-Control-Allow-Origin', '*');

      await request.drain<void>();

      if (request.requestedUri.pathSegments.isNotEmpty) {
        request.response.write(request.requestedUri.pathSegments.last);
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      await request.response.close();
    });

  channel.sink.add(server.port);
  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close());
}
