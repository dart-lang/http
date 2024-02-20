// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
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
  late final HttpServer server;
  server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      var key = request.headers.value('Sec-WebSocket-Key');
      var digest = sha1.convert("$key$WEB_SOCKET_GUID".codeUnits);
      var accept = base64.encode(digest.bytes);
      request.response
        ..statusCode = HttpStatus.switchingProtocols
        ..headers.add(HttpHeaders.connectionHeader, "Upgrade")
        ..headers.add(HttpHeaders.upgradeHeader, "websocket")
        ..headers.add("Sec-WebSocket-Accept", accept);
      request.response.contentLength = 0;
//      await request.response.close();
      final socket = await request.response.detachSocket();
//      socket.write('\r\n');
//      socket.write('\r\n');
//      final websocket = WebSocket.fromUpgradedSocket(socket, serverSide: true);
//      websocket.listen((x) => print('server received: $x'));
      socket.write('marry had a little lamb whose fleece was white as snow');
    });

  channel.sink.add(server.port);

  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close());
}
