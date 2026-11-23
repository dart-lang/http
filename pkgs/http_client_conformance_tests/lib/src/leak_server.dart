// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';

const _chunkSize = 1024 * 1024;

/// Starts an HTTP server used by leak tests.
///
/// `POST` drains the request body and responds with the received byte count.
/// `GET` responds with `length` bytes as specified by the `length` query
/// parameter.
///
/// Channel protocol:
///    On Startup:
///     - send port
///    When Receive Anything:
///     - exit
void hybridMain(StreamChannel<Object?> channel) async {
  final responseChunk = Uint8List(_chunkSize);
  // Touch each 4 KB page with a non-zero byte so OS zero-page deduplication
  // and compression cannot hide leaked response buffers from RSS checks.
  for (var offset = 0; offset < responseChunk.length; offset += 4096) {
    responseChunk[offset] = ((offset >> 12) & 0xff) | 1;
  }
  final server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      if (request.method == 'OPTIONS') {
        request.response.headers
          ..set('Access-Control-Allow-Methods', 'GET, POST')
          ..set('Access-Control-Allow-Headers', 'Content-Type');
        await request.response.close();
        return;
      }

      if (request.method == 'POST') {
        var received = 0;
        await for (final chunk in request) {
          received += chunk.length;
        }
        request.response.headers.set('Content-Type', 'text/plain');
        request.response.write('$received');
        await request.response.close();
        return;
      }

      await request.drain<void>();
      final length = int.parse(request.requestedUri.queryParameters['length']!);
      request.response.headers.set('Content-Type', 'application/octet-stream');
      request.response.contentLength = length;
      var remaining = length;
      while (remaining >= _chunkSize) {
        request.response.add(responseChunk);
        remaining -= _chunkSize;
      }
      if (remaining > 0) {
        request.response.add(
          Uint8List.sublistView(responseChunk, 0, remaining),
        );
      }
      await request.response.close();
    });

  channel.sink.add(server.port);
  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close(force: true));
}
