// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

/// Starts an HTTP server that captures the content type header and request
/// body.
///
/// Channel protocol:
///    On Startup:
///     - send port
///    On Request Received:
///     - send "Content-Type" header
///     - send request body
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
          ..set('Access-Control-Allow-Methods', 'POST, DELETE')
          ..set('Access-Control-Allow-Headers', 'Content-Type');
      } else {
        channel.sink.add(request.headers[HttpHeaders.contentTypeHeader]);
        try {
          final serverReceivedBody = await const Utf8Decoder()
              .bind(request)
              .fold('', (p, e) => '$p$e');
          channel.sink.add(serverReceivedBody);
        } on HttpException catch (e) {
          // The server may through if the client disconnections.
          // This can happen if there is an error in the request
          // stream.
          print('Request Body Server Exception: $e');
          return;
        }
      }
      unawaited(request.response.close());
    });

  channel.sink.add(server.port);
  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close());
}
