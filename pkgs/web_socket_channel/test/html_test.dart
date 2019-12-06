// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')

import 'dart:async';
import 'dart:html';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:test/test.dart';

import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  int port;
  setUpAll(() async {
    var channel = spawnHybridCode(r'''
      import 'dart:io';

      import 'package:stream_channel/stream_channel.dart';

      hybridMain(StreamChannel channel) async {
        var server = await HttpServer.bind('localhost', 0);
        server.transform(WebSocketTransformer()).listen((webSocket) {
          webSocket.listen((request) {
            webSocket.add(request);
          });
        });
        channel.sink.add(server.port);
      }
    ''', stayAlive: true);

    port = await channel.stream.first;
  });

  WebSocketChannel channel;
  tearDown(() {
    if (channel != null) channel.sink.close();
  });

  test('communicates using an existing WebSocket', () async {
    var webSocket = WebSocket('ws://localhost:$port');
    channel = HtmlWebSocketChannel(webSocket);

    var queue = StreamQueue(channel.stream);
    channel.sink.add('foo');
    expect(await queue.next, equals('foo'));

    channel.sink.add(Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(await _decodeBlob(await queue.next), equals([1, 2, 3, 4, 5]));

    webSocket.binaryType = 'arraybuffer';
    channel.sink.add(Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(await queue.next, equals([1, 2, 3, 4, 5]));
  });

  test('communicates using an existing open WebSocket', () async {
    var webSocket = WebSocket('ws://localhost:$port');
    await webSocket.onOpen.first;

    channel = HtmlWebSocketChannel(webSocket);

    var queue = StreamQueue(channel.stream);
    channel.sink.add('foo');
    expect(await queue.next, equals('foo'));
  });

  test('.connect defaults to binary lists', () async {
    channel = HtmlWebSocketChannel.connect('ws://localhost:$port');

    var queue = StreamQueue(channel.stream);
    channel.sink.add('foo');
    expect(await queue.next, equals('foo'));

    channel.sink.add(Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(await queue.next, equals([1, 2, 3, 4, 5]));
  });

  test('.connect defaults to binary lists using platform independent api',
      () async {
    channel = WebSocketChannel.connect(Uri.parse('ws://localhost:$port'));

    var queue = StreamQueue(channel.stream);
    channel.sink.add('foo');
    expect(await queue.next, equals('foo'));

    channel.sink.add(Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(await queue.next, equals([1, 2, 3, 4, 5]));
  });

  test('.connect can use blobs', () async {
    channel = HtmlWebSocketChannel.connect('ws://localhost:$port',
        binaryType: BinaryType.blob);

    var queue = StreamQueue(channel.stream);
    channel.sink.add('foo');
    expect(await queue.next, equals('foo'));

    channel.sink.add(Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(await _decodeBlob(await queue.next), equals([1, 2, 3, 4, 5]));
  });

  test('.connect wraps a connection error in WebSocketChannelException',
      () async {
    // Spawn a server that will immediately reject the connection.
    var serverChannel = spawnHybridCode(r'''
      import 'dart:io';

      import 'package:stream_channel/stream_channel.dart';

      hybridMain(StreamChannel channel) async {
        var server = await ServerSocket.bind('localhost', 0);
        server.listen((socket) {
          socket.close();
        });
        channel.sink.add(server.port);
      }
    ''');

    // TODO(nweiz): Make this channel use a port number that's guaranteed to be
    // invalid.
    var channel = HtmlWebSocketChannel.connect(
        'ws://localhost:${await serverChannel.stream.first}');
    expect(channel.stream.toList(),
        throwsA(TypeMatcher<WebSocketChannelException>()));
  });
}

Future<List<int>> _decodeBlob(Blob blob) async {
  var reader = FileReader();
  reader.readAsArrayBuffer(blob);
  await reader.onLoad.first;
  return reader.result as Uint8List;
}
