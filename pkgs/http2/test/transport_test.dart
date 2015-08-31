// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE FILE.

import 'dart:async';

import 'package:test/test.dart';

import 'package:http2/transport.dart';

main() {
  group('transport-test', () {
    transportTest('ping', (TransportConnection client,
                           TransportConnection server) async {
      await client.ping();
      await server.ping();
    });
    transportTest('terminated-client-ping', (TransportConnection client,
                                             TransportConnection server) async {
      var clientError = client.ping().catchError(expectAsync((e, s) {
        expect(e is TransportException, isTrue);
      }));
      await client.terminate();
      await clientError;

      // NOTE: Now the connection is dead and client/server should complete
      // with [TransportException]s when doing work (e.g. ping).
      client.ping().catchError(expectAsync((e, s) {
        expect(e is TransportException, isTrue);
      }));
      server.ping().catchError(expectAsync((e, s) {
        expect(e is TransportException, isTrue);
      }));
    });
    transportTest('terminated-server-ping', (TransportConnection client,
                                             TransportConnection server) async {
      var clientError = client.ping().catchError(expectAsync((e, s) {
        expect(e is TransportException, isTrue);
      }));
      await server.terminate();
      await clientError;

      // NOTE: Now the connection is dead and the client/server should complete
      // with [TransportException]s when doing work (e.g. ping).
      client.ping().catchError(expectAsync((e, s) {
        expect(e is TransportException, isTrue);
      }));
      server.ping().catchError(expectAsync((e, s) {
        expect(e is TransportException, isTrue);
      }));
    });
  });
}

transportTest(String name, func(client, server)) {
  return test(name, () {
    var bidirectional = new BidirectionalConnection();
    var client = bidirectional.clientConnection;
    var server = bidirectional.serverConnection;
    return func(client, server);
  });
}

class BidirectionalConnection {
  final StreamController<List<int>> writeA = new StreamController();
  final StreamController<List<int>> writeB = new StreamController();
  Stream<List<int>> get readA => writeA.stream;
  Stream<List<int>> get readB => writeB.stream;

  TransportConnection get clientConnection
      => new ClientTransportConnection.viaStreams(readA, writeB.sink);

  TransportConnection get serverConnection
      => new ServerTransportConnection.viaStreams(readB, writeA.sink);
}
