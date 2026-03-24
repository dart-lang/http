// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';
import 'package:web_socket_conformance_tests/web_socket_conformance_tests.dart';

void runTests(
  Future<WebSocket> Function(Uri uri, {Iterable<String>? protocols})
  webSocketFactory,
) {
  if (Platform.isMacOS) {
    // TODO(https://github.com/dart-lang/http/issues/1814): Fix web socket tests
    // on macOS.
    testCloseRemote(webSocketFactory);
    testConnectUri(webSocketFactory);
    testDisconnectAfterUpgrade(webSocketFactory);
    testNoUpgrade(webSocketFactory);
    testPayloadTransfer(webSocketFactory);
    testPeerProtocolErrors(webSocketFactory);
    testProtocols(webSocketFactory);
  } else {
    testAll(webSocketFactory);
  }
}

void main() {
  group('defaultSessionConfiguration', () {
    runTests(CupertinoWebSocket.connect);
  });
  group('fromSessionConfiguration', () {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration();
    runTests(
      (uri, {protocols}) =>
          CupertinoWebSocket.connect(uri, protocols: protocols, config: config),
    );
  });
}
