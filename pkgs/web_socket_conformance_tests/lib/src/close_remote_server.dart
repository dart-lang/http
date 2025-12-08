// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:stream_channel/stream_channel.dart';

const _webSocketGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

/// Starts an WebSocket server that sends a Close frame after receiving any
/// data.
void hybridMain(StreamChannel<Object?> channel) async {
  late HttpServer server;

  server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      if (request.uri.queryParameters.containsKey('invalidUTF8')) {
        final key = request.headers.value('Sec-WebSocket-Key');
        final accept = base64
            .encode(sha1.convert(utf8.encode(key! + _webSocketGuid)).bytes);
        request.response
          ..statusCode = HttpStatus.switchingProtocols
          ..headers.add('Upgrade', 'websocket')
          ..headers.add('Connection', 'Upgrade')
          ..headers.add('Sec-WebSocket-Accept', accept);
        final socket = await request.response.detachSocket();
        var sent = false;
        socket.listen((events) {
          if (sent) return;
          sent = true;
          // Send a Close frame (opcode 8) with a 2 byte code (4123) and
          // 1 byte that is invalid UTF-8 (0xFF).
          socket.add([0x88, 0x03, 0x10, 0x1B, 0xFF]);
          socket.close();
        });
        return;
      }

      final webSocket = await WebSocketTransformer.upgrade(
        request,
      );

      webSocket.listen((event) {
        channel.sink.add(event);
        webSocket.close(4123, 'server closed the connection');
      });
    });

  channel.sink.add(server.port);
  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close());
}
