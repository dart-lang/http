// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

/// Starts an HTTP server that captures the request headers and body.
///
/// Channel protocol:
///    On Startup:
///     - send port
///    On Request Received:
///     - send the received headers and request body
///    When Receive Anything:
///     - exit
void hybridMain(StreamChannel<Object?> channel) async {
  late HttpServer server;

  server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      if (request.method == 'OPTIONS') {
        // Handle a CORS preflight request:
        // https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#preflighted_requests
        request.response.headers
          ..set('Access-Control-Allow-Methods', '*')
          ..set('Access-Control-Allow-Headers', '*');
      } else {
        final headers = <String, List<String>>{};
        request.headers.forEach((field, value) {
          headers[field] = value;
        });
        final body =
            await const Utf8Decoder().bind(request).fold('', (x, y) => '$x$y');
        channel.sink.add((headers, body));
      }
      unawaited(request.response.close());
    });

  channel.sink.add(server.port);
  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close());
}
