// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE FILE.

/// ---------------------------------------------------------------------------
/// In order to run this test one needs to change the following line in
/// ../lib/src/streams/stream_handler.dart
///
///    -  static const int MAX_STREAM_ID = (1 << 31) - 1;
///    +  static const int MAX_STREAM_ID = (1 << 5) - 1;
///
/// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:test/test.dart';
import 'package:http2/transport.dart';

import '../test/transport_test.dart';

main() {
  group('transport-test', () {
    transportTest('client-runs-out-of-stream-ids',
        (ClientTransportConnection client,
            ServerTransportConnection server) async {
      Future serverFun() async {
        await for (ServerTransportStream stream in server.incomingStreams) {
          stream.sendHeaders([new Header.ascii('x', 'y')], endStream: true);
          expect(await stream.incomingMessages.toList(), hasLength(1));
        }
        await server.finish();
      }

      Future clientFun() async {
        var headers = [new Header.ascii('a', 'b')];

        const kMaxStreamId = (1 << 5) - 1;
        for (int i = 1; i <= kMaxStreamId; i += 2) {
          var stream = client.makeRequest(headers, endStream: true);
          var messages = await stream.incomingMessages.toList();
          expect(messages, hasLength(1));
        }

        expect(client.isOpen, false);
        expect(() => client.makeRequest(headers),
            throwsA(new isInstanceOf<StateError>()));

        await new Future.delayed(const Duration(seconds: 1));
        await client.finish();
      }

      var serverFuture = serverFun();
      var clientFuture = clientFun();

      await serverFuture;
      await clientFuture;
    });
  });
}
