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
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Access-Control-Expose-Headers', '*');

      (await clientQueue.next as Map).forEach((key, value) => request
          .response.headers
          .set(key as String, value as String, preserveHeaderCase: true));

      await request.response.close();
      unawaited(server.close());
    });

  channel.sink.add(server.port);
}
