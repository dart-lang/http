// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import "package:crypto/crypto.dart";
import 'package:stream_channel/stream_channel.dart';

const WEB_SOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

/// Starts an WebSocket server that echos the payload of the request.
///
/// Channel protocol:
///    On Startup:
///     - send port
///    On Request Received:
///     - echoes the request payload
///    When Receive Anything:
///     - exit
void hybridMain(StreamChannel<Object?> channel) async {
  final server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      request.response.statusCode = 200;
      request.response.close();
    });
  channel.sink.add(server.port);

  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close());
}
