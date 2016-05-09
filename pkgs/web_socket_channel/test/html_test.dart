// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
@Skip(
    "This suite requires a WebSocket server, which is currently unsupported\n"
    "by the test package (dart-lang/test#330). It's currently set up to talk\n"
    "to a hard-coded server on localhost:1234 that is spawned in \n"
    "html_test_server.dart.")

import 'dart:async';
import 'dart:html';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:test/test.dart';

import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  var channel;
  tearDown(() {
    if (channel != null) channel.sink.close();
  });

  test("communicates using an existing WebSocket", () async {
    var webSocket = new WebSocket("ws://localhost:1234");
    channel = new HtmlWebSocketChannel(webSocket);

    var queue = new StreamQueue(channel.stream);
    channel.sink.add("foo");
    expect(await queue.next, equals("foo"));

    channel.sink.add(new Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(await _decodeBlob(await queue.next), equals([1, 2, 3, 4, 5]));

    webSocket.binaryType = "arraybuffer";
    channel.sink.add(new Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(await queue.next, equals([1, 2, 3, 4, 5]));
  });

  test("communicates using an existing open WebSocket", () async {
    var webSocket = new WebSocket("ws://localhost:1234");
    await webSocket.onOpen.first;

    channel = new HtmlWebSocketChannel(webSocket);

    var queue = new StreamQueue(channel.stream);
    channel.sink.add("foo");
    expect(await queue.next, equals("foo"));
  });

  test(".connect defaults to binary lists", () async {
    channel = new HtmlWebSocketChannel.connect("ws://localhost:1234");

    var queue = new StreamQueue(channel.stream);
    channel.sink.add("foo");
    expect(await queue.next, equals("foo"));

    channel.sink.add(new Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(await queue.next, equals([1, 2, 3, 4, 5]));
  });

  test(".connect can use blobs", () async {
    channel = new HtmlWebSocketChannel.connect(
        "ws://localhost:1234", binaryType: BinaryType.blob);

    var queue = new StreamQueue(channel.stream);
    channel.sink.add("foo");
    expect(await queue.next, equals("foo"));

    channel.sink.add(new Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(await _decodeBlob(await queue.next), equals([1, 2, 3, 4, 5]));
  });

  test(".connect wraps a connection error in WebSocketChannelException",
      () async {
    // TODO(nweiz): Make this channel use a port number that's guaranteed to be
    // invalid.
    var channel = new HtmlWebSocketChannel.connect("ws://localhost:1235");
    expect(channel.stream.toList(),
        throwsA(new isInstanceOf<WebSocketChannelException>()));
  });
}

Future<List<int>> _decodeBlob(Blob blob) async {
  var reader = new FileReader();
  reader.readAsArrayBuffer(blob);
  await reader.onLoad.first;
  return reader.result as Uint8List;
}
