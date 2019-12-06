// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'dart:io';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('using WebSocketChannel', () {
    test('a client can communicate with a WebSocket server', () async {
      var server = await HttpServer.bind('localhost', 0);
      server.transform(WebSocketTransformer()).listen((webSocket) {
        webSocket.add('hello!');
        webSocket.listen((request) {
          expect(request, equals('ping'));
          webSocket.add('pong');
          webSocket.close();
        });
      });

      var client = HttpClient();
      var request = await client.openUrl(
          'GET', Uri.parse('http://localhost:${server.port}'));
      request.headers
        ..set('Connection', 'Upgrade')
        ..set('Upgrade', 'websocket')
        ..set('Sec-WebSocket-Key', 'x3JJHMbDL1EzLkh9GBhXDw==')
        ..set('Sec-WebSocket-Version', '13');

      var response = await request.close();
      var socket = await response.detachSocket();
      var innerChannel = StreamChannel<List<int>>(socket, socket);
      var webSocket = WebSocketChannel(innerChannel, serverSide: false);

      var n = 0;
      await webSocket.stream.listen((message) {
        if (n == 0) {
          expect(message, equals('hello!'));
          webSocket.sink.add('ping');
        } else if (n == 1) {
          expect(message, equals('pong'));
          webSocket.sink.close();
          server.close();
        } else {
          fail('Only expected two messages.');
        }
        n++;
      }).asFuture();
    });

    test('a server can communicate with a WebSocket client', () async {
      var server = await HttpServer.bind('localhost', 0);
      server.listen((request) async {
        var response = request.response;
        response.statusCode = 101;
        response.headers
          ..set('Connection', 'Upgrade')
          ..set('Upgrade', 'websocket')
          ..set(
              'Sec-WebSocket-Accept',
              WebSocketChannel.signKey(
                  request.headers.value('Sec-WebSocket-Key')));
        response.contentLength = 0;

        var socket = await response.detachSocket();
        var innerChannel = StreamChannel<List<int>>(socket, socket);
        var webSocket = WebSocketChannel(innerChannel);
        webSocket.sink.add('hello!');

        var message = await webSocket.stream.first;
        expect(message, equals('ping'));
        webSocket.sink.add('pong');
        await webSocket.sink.close();
      });

      var webSocket = await WebSocket.connect('ws://localhost:${server.port}');
      var n = 0;
      await webSocket.listen((message) {
        if (n == 0) {
          expect(message, equals('hello!'));
          webSocket.add('ping');
        } else if (n == 1) {
          expect(message, equals('pong'));
          webSocket.close();
          server.close();
        } else {
          fail('Only expected two messages.');
        }
        n++;
      }).asFuture();
    });
  });
}
