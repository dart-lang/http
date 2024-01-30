// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:web_socket_conformance_tests/src/disconnect_after_upgrade_tests.dart';
import 'package:websocket/websocket.dart';

// import 'src/failure_tests.dart';
// import 'src/close_tests.dart';
import 'src/close_local_tests.dart';
import 'src/close_remote_tests.dart';
import 'src/no_upgrade_tests.dart';
import 'src/payload_transfer_tests.dart';
import 'src/peer_protocol_errors_tests.dart';

// import 'src/protocol_tests.dart';

/// Runs the entire test suite against the given [WebSocketChannel].
void testAll(
    Future<WebSocket> Function(Uri uri, {Iterable<String>? protocols})
        webSocketFactory) {
  testPayloadTransfer(webSocketFactory);
  testLocalClose(webSocketFactory);
  testRemoteClose(webSocketFactory);
//  testProtocols(channelFactory);
  testNoUpgrade(webSocketFactory);
  testDisconnectAfterUpgrade(webSocketFactory);
  testPeerProtocolErrors(webSocketFactory);
}
