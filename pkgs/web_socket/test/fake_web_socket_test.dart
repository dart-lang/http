// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:web_socket/src/fake_web_socket.dart';
import 'package:web_socket/web_socket.dart';
import 'package:web_socket_conformance_tests/web_socket_conformance_tests.dart';

/// Forward data received from [from] to [to].
void proxy(WebSocket from, WebSocket to) {
  from.events.listen((event) {
    try {
      switch (event) {
        case TextDataReceived(:final text):
          to.sendText(text);
        case BinaryDataReceived(:final data):
          to.sendBytes(data);
        case CloseReceived(:var code, :final reason):
          if (code != null && code != 1000 && (code < 3000 || code > 4999)) {
            code = null;
          }
          to.close(code, reason);
      }
    } on WebSocketConnectionClosed {
      // `to` may have been closed locally so ignore failures to forward the
      // data.
    }
  });
}

/// Create a bidirectional proxy relationship between [a] and [b].
///
/// That means that events received by [a] will be forwarded to [b] and
/// vise-versa.
void bidirectionalProxy(WebSocket a, WebSocket b) {
  proxy(a, b);
  proxy(b, a);
}

void main() {
  // In order to use `testAll`, we need to provide a method that will connect
  // to a real WebSocket server.
  //
  // The approach is to connect to the server with a real WebSocket and forward
  // the data received by that data to one of the fakes.
  //
  // Like:
  //
  //         'hello'            sendText('hello')   TextDataReceived('hello')
  // [Server]  ->   [realClient]        ->       [FakeServer]  ->   [fakeClient]
  Future<WebSocket> connect(Uri url, {Iterable<String>? protocols}) async {
    final realClient = await WebSocket.connect(url, protocols: protocols);
    final (fakeServer, fakeClient) = fakes(protocol: realClient.protocol);
    bidirectionalProxy(realClient, fakeServer);
    return fakeClient;
  }

  testAll(connect);
}
