// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

/// Starts an HTTP server and sends the port back on the given channel.
///
/// Quits when anything is received on the channel.
///
///        URI |  Redirects TO
/// ===========|==============
/// ".../loop" |    ".../loop"
///   ".../10" |       ".../9"
///    ".../9" |       ".../8"
///        ... |           ...
///    ".../1" |           "/"
///        "/" |  <200 return>
void hybridMain(StreamChannel<Object?> channel) async {
  late HttpServer server;

  server = await HttpServer.bind('localhost', 0)
    ..listen((request) async {
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      if (request.requestedUri.pathSegments.isEmpty) {
        unawaited(request.response.close());
      } else if (request.requestedUri.pathSegments.last == 'loop') {
        unawaited(request.response
            .redirect(Uri.http('localhost:${server.port}', '/loop')));
      } else {
        final n = int.parse(request.requestedUri.pathSegments.last);
        final nextPath = n - 1 == 0 ? '' : '${n - 1}';
        unawaited(request.response
            .redirect(Uri.http('localhost:${server.port}', '/$nextPath')));
      }
    });

  channel.sink.add(server.port);
  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close());
}
