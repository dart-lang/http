// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE FILE.

import 'dart:async';

import 'package:test/test.dart';
import 'package:http2/transport.dart';

import 'src/hpack/hpack_test.dart' show isHeader;

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

    transportTest('disabled-push', (ClientTransportConnection client,
                                    ServerTransportConnection server) async {
      server.incomingStreams.listen(
          expectAsync((ServerTransportStream stream) async {
        expect(stream.canPush, false);
        expect(() => stream.push([new Header.ascii('a', 'b')]), throws);
        stream.sendHeaders([new Header.ascii('x', 'y')], endStream: true);
      }));

      var stream = client.makeRequest(
          [new Header.ascii('a', 'b')], endStream: true);

      var messages = await stream.incomingMessages.toList();
      expect(messages, hasLength(1));
      expect(messages[0] is HeadersStreamMessage, true);
      expect((messages[0] as HeadersStreamMessage).headers[0],
             isHeader('x', 'y'));

      expect(await stream.peerPushes.toList(), isEmpty);
    });

    // By default, the stream concurrency level is set to this limit.
    const int kDefaultStreamLimit = 100;
    transportTest('enabled-push-100', (ClientTransportConnection client,
                                       ServerTransportConnection server) async {
      // To ensure the limit is kept up-to-date with closing/opening streams, we
      // retry this.
      const int kRepetitions = 20;

      Future serverFun() async {
        await for (ServerTransportStream stream in server.incomingStreams) {
          var pushes = [];
          for (int i = 0; i < kDefaultStreamLimit; i++) {
            expect(stream.canPush, true);
            pushes.add(stream.push([new Header.ascii('a', 'b')]));
          }

          // Now we should have reached the limit and we should not be able to
          // create more pushes.
          expect(stream.canPush, false);
          expect(() => stream.push([new Header.ascii('a', 'b')]), throws);

          // Finish the pushes
          for (ServerTransportStream pushedStream in pushes) {
            pushedStream.sendHeaders(
                [new Header.ascii('e', 'nd')], endStream: true);
            await pushedStream.incomingMessages.toList();
          }

          // Finish the stream.
          stream.sendHeaders([new Header.ascii('x', 'y')], endStream: true);
          expect(await stream.incomingMessages.toList(), hasLength(1));
        }
      }

      Future clientFun() async {
        for (int i = 0; i < kRepetitions; i++) {
          var stream = client.makeRequest(
              [new Header.ascii('a', 'b')], endStream: true);

          Future<int> expectPeerPushes() async {
            int numberOfPushes = 0;
            await for (TransportStreamPush pushedStream in stream.peerPushes) {
              numberOfPushes++;
              var messages =
                  await pushedStream.stream.incomingMessages.toList();
              expect(messages, hasLength(1));
              expect((messages[0] as HeadersStreamMessage).headers[0],
                     isHeader('e', 'nd'));
              expect(await pushedStream.stream.peerPushes.toList(), isEmpty);
            }
            return numberOfPushes;
          }

          // Wait for the end of the normal stream.
          var messages = await stream.incomingMessages.toList();
          expect(messages, hasLength(1));
          expect(messages[0] is HeadersStreamMessage, true);
          expect((messages[0] as HeadersStreamMessage).headers[0],
                 isHeader('x', 'y'));

          expect(await expectPeerPushes(), kDefaultStreamLimit);
        }
      }

      var serverFuture = serverFun();

      await clientFun();
      await client.terminate();
      await serverFuture;
    }, clientSettings: new ClientSettings(kDefaultStreamLimit, true));
  });
}

transportTest(String name,
              func(client, server),
              {ClientSettings clientSettings,
               ServerSettings serverSettings}) {
  return test(name, () {
    var bidirectional = new BidirectionalConnection();
    bidirectional.clientSettings = clientSettings;
    bidirectional.serverSettings = serverSettings;
    var client = bidirectional.clientConnection;
    var server = bidirectional.serverConnection;
    return func(client, server);
  });
}

class BidirectionalConnection {
  ClientSettings clientSettings;
  ServerSettings serverSettings;

  final StreamController<List<int>> writeA = new StreamController();
  final StreamController<List<int>> writeB = new StreamController();
  Stream<List<int>> get readA => writeA.stream;
  Stream<List<int>> get readB => writeB.stream;

  ClientTransportConnection get clientConnection
      => new ClientTransportConnection.viaStreams(
          readA,
          writeB.sink, settings: clientSettings);

  ServerTransportConnection get serverConnection
      => new ServerTransportConnection.viaStreams(
          readB, writeA.sink, settings: serverSettings);
}

