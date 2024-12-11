// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' hide BinaryType;
import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

extension on StreamChannel {
  /// Handles the Wasm case where the runtime type is actually [double] instead
  /// of the JS case where its [int].
  Future<int> get firstAsInt async => ((await stream.first) as num).toInt();
}

void main() {
  late int port;
  setUpAll(() async {
    final channel = spawnHybridCode(r'''
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

    port = await channel.firstAsInt;
  });

  test('communicates using an existing WebSocket', () async {
    final webSocket = WebSocket('ws://localhost:$port');
    final channel = HtmlWebSocketChannel(webSocket);

    expect(channel.ready, completes);

    addTearDown(channel.sink.close);

    final queue = StreamQueue(channel.stream);
    channel.sink.add('foo');
    expect(await queue.next, equals('foo'));

    channel.sink.add(Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(
      await _decodeBlob(await queue.next as Blob),
      equals([1, 2, 3, 4, 5]),
    );

    webSocket.binaryType = 'arraybuffer';
    channel.sink.add(Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(await queue.next, equals([1, 2, 3, 4, 5]));
  });

  test('communicates using an existing open WebSocket', () async {
    final webSocket = WebSocket('ws://localhost:$port');
    await webSocket.onOpen.first;

    final channel = HtmlWebSocketChannel(webSocket);

    expect(channel.ready, completes);

    addTearDown(channel.sink.close);

    final queue = StreamQueue(channel.stream);
    channel.sink.add('foo');
    expect(await queue.next, equals('foo'));
  });

  test('communicates using an connecting WebSocket', () async {
    final webSocket = WebSocket('ws://localhost:$port');

    final channel = HtmlWebSocketChannel(webSocket);

    expect(channel.ready, completes);

    addTearDown(channel.sink.close);
  });

  test('communicates using an existing closed WebSocket', () async {
    final webSocket = WebSocket('ws://localhost:$port');
    webSocket.close();

    final channel = HtmlWebSocketChannel(webSocket);
    await expectLater(
      channel.ready,
      throwsA(
        isA<WebSocketChannelException>()
            .having((p0) => p0.message, 'message', 'WebSocket state error: 2')
            .having((p0) => p0.inner, 'inner', isNull),
      ),
    );
  });

  test('.connect defaults to binary lists', () async {
    final channel = HtmlWebSocketChannel.connect('ws://localhost:$port');

    expect(channel.ready, completes);

    addTearDown(channel.sink.close);

    final queue = StreamQueue(channel.stream);
    channel.sink.add('foo');
    expect(await queue.next, equals('foo'));

    channel.sink.add(Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(await queue.next, equals([1, 2, 3, 4, 5]));
  });

  test('.connect defaults to binary lists using platform independent api',
      () async {
    final channel = WebSocketChannel.connect(Uri.parse('ws://localhost:$port'));

    expect(channel.ready, completes);

    addTearDown(channel.sink.close);

    final queue = StreamQueue(channel.stream);
    channel.sink.add('foo');
    expect(await queue.next, equals('foo'));

    channel.sink.add(Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(await queue.next, equals([1, 2, 3, 4, 5]));
  });

  test('.connect can use blobs', () async {
    final channel = HtmlWebSocketChannel.connect('ws://localhost:$port',
        binaryType: BinaryType.blob);

    expect(channel.ready, completes);

    addTearDown(channel.sink.close);

    final queue = StreamQueue(channel.stream);
    channel.sink.add('foo');
    expect(await queue.next, equals('foo'));

    channel.sink.add(Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(
        await _decodeBlob(await queue.next as Blob), equals([1, 2, 3, 4, 5]));
  });

  test('.connect wraps a connection error in WebSocketChannelException',
      () async {
    // Spawn a server that will immediately reject the connection.
    final serverChannel = spawnHybridCode(r'''
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
    final channel = HtmlWebSocketChannel.connect(
        'ws://localhost:${await serverChannel.firstAsInt}');
    expect(channel.ready, throwsA(isA<WebSocketChannelException>()));
    expect(channel.stream.toList(), throwsA(isA<WebSocketChannelException>()));
  });
}

Future<List<int>> _decodeBlob(Blob blob) async {
  final reader = FileReader();
  reader.readAsArrayBuffer(blob);
  await reader.onLoadEnd.first;
  return (reader.result as JSArrayBuffer).toDart.asUint8List();
}
