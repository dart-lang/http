// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:io' as io;

import 'package:test/test.dart';
import 'package:web_socket/io_web_socket.dart';
import 'package:web_socket/web_socket.dart';

void main() {
  group('fromWebSocket', () {
    late final io.HttpServer server;
    late io.HttpHeaders headers;
    late Uri uri;

    setUp(() async {
      server = (await io.HttpServer.bind('localhost', 0))
        ..listen((request) async {
          headers = request.headers;
          await io.WebSocketTransformer.upgrade(request)
              .then((webSocket) => webSocket.listen(webSocket.add));
        });
      uri = Uri.parse('ws://localhost:${server.port}');
    });

    test('custom headers', () async {
      final ws = IOWebSocket.fromWebSocket(await io.WebSocket.connect(
          uri.toString(),
          headers: {'fruit': 'apple'}));
      expect(headers['fruit'], ['apple']);
      ws.sendText('Hello World!');
      expect(await ws.events.first, TextDataReceived('Hello World!'));
      await ws.close();
    });
  });
}
