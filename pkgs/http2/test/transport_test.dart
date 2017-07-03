// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE FILE.

import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:http2/transport.dart';
import 'package:http2/src/flowcontrol/window.dart';

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
      var clientError = client.ping().catchError(expectAsync2((e, s) {
        expect(e is TransportException, isTrue);
      }));
      await client.terminate();
      await clientError;

      // NOTE: Now the connection is dead and client/server should complete
      // with [TransportException]s when doing work (e.g. ping).
      client.ping().catchError(expectAsync2((e, s) {
        expect(e is TransportException, isTrue);
      }));
      server.ping().catchError(expectAsync2((e, s) {
        expect(e is TransportException, isTrue);
      }));
    });

    transportTest('terminated-server-ping', (TransportConnection client,
                                             TransportConnection server) async {
      var clientError = client.ping().catchError(expectAsync2((e, s) {
        expect(e is TransportException, isTrue);
      }));
      await server.terminate();
      await clientError;

      // NOTE: Now the connection is dead and the client/server should complete
      // with [TransportException]s when doing work (e.g. ping).
      client.ping().catchError(expectAsync2((e, s) {
        expect(e is TransportException, isTrue);
      }));
      server.ping().catchError(expectAsync2((e, s) {
        expect(e is TransportException, isTrue);
      }));
    });

    transportTest('disabled-push', (ClientTransportConnection client,
                                    ServerTransportConnection server) async {
      server.incomingStreams.listen(
          expectAsync1((ServerTransportStream stream) async {
        expect(stream.canPush, false);
        expect(() => stream.push([new Header.ascii('a', 'b')]),
            throwsA(new isInstanceOf<StateError>()));
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
          expect(() => stream.push([new Header.ascii('a', 'b')]),
              throwsA(new isInstanceOf<StateError>()));

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
    }, clientSettings: new ClientSettings(
        concurrentStreamLimit: kDefaultStreamLimit,
        allowServerPushes: true));

    transportTest('early-shutdown',
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
        var stream = client.makeRequest(headers, endStream: true);
        var finishFuture = client.finish();
        var messages = await stream.incomingMessages.toList();
        expect(messages, hasLength(1));
        await finishFuture;
      }

      await Future.wait([serverFun(), clientFun()]);
    });

    transportTest('client-terminates-stream',
        (ClientTransportConnection client,
         ServerTransportConnection server) async {

      var readyForError = new Completer();

      Future serverFun() async {
        await for (ServerTransportStream stream in server.incomingStreams) {
          stream.sendHeaders([new Header.ascii('x', 'y')], endStream: true);
          stream.incomingMessages.listen(expectAsync1((msg) {
            expect(msg is HeadersStreamMessage, true);
            readyForError.complete();
          }), onError: expectAsync1((error) {
            expect('$error', contains('Stream was terminated by peer'));
          }));
        }
        await server.finish();
      }

      Future clientFun() async {
        var headers = [new Header.ascii('a', 'b')];
        var stream = client.makeRequest(headers, endStream: false);
        await readyForError.future;
        stream.terminate();
        await client.finish();
      }

      await Future.wait([serverFun(), clientFun()]);
    });

    transportTest('server-terminates-stream',
        (ClientTransportConnection client,
         ServerTransportConnection server) async {

      Future serverFun() async {
        await for (ServerTransportStream stream in server.incomingStreams) {
          stream.terminate();
        }
        await server.finish();
      }

      Future clientFun() async {
        var headers = [new Header.ascii('a', 'b')];
        var stream = client.makeRequest(headers, endStream: true);
        await stream.incomingMessages.toList().catchError(expectAsync1((error) {
          expect('$error', contains('Stream was terminated by peer'));
        }));
        await client.finish();
      }

      await Future.wait([serverFun(), clientFun()]);
    });

    transportTest('client-terminates-stream-after-half-close',
        (ClientTransportConnection client,
         ServerTransportConnection server) async {

      var readyForError = new Completer();

      Future serverFun() async {
        await for (ServerTransportStream stream in server.incomingStreams) {
          stream.onTerminated = expectAsync1((errorCode) {
            expect(errorCode, 8);
          }, count: 1);
          stream.sendHeaders([new Header.ascii('x', 'y')], endStream: false);
          stream.incomingMessages.listen(
            expectAsync1((msg) {
              expect(msg is HeadersStreamMessage, true);
            }),
            onError: expectAsync1((_) {}, count: 0),
            onDone: expectAsync0(() {
              readyForError.complete();
            }, count: 1),
          );
        }
        await server.finish();
      }

      Future clientFun() async {
        var headers = [new Header.ascii('a', 'b')];
        var stream = client.makeRequest(headers, endStream: true);
        await stream.outgoingMessages.close();
        await readyForError.future;
        stream.terminate();
        await client.finish();
      }

      await Future.wait([serverFun(), clientFun()]);
    });

    transportTest('server-terminates-stream-after-half-close',
        (ClientTransportConnection client,
         ServerTransportConnection server) async {

          var readyForError = new Completer();

          Future serverFun() async {
            await for (ServerTransportStream stream in server.incomingStreams) {
              stream.sendHeaders([new Header.ascii('x', 'y')], endStream: false);
              stream.incomingMessages.listen(
                expectAsync1((msg) async {
                  expect(msg is HeadersStreamMessage, true);
                  await readyForError.future;
                  stream.terminate();
                }),
                onError: expectAsync1((_) {}, count: 0),
                onDone: expectAsync0(() {}, count: 1),
              );
            }
            await server.finish();
          }

          Future clientFun() async {
            var headers = [new Header.ascii('a', 'b')];
            var stream = client.makeRequest(headers, endStream: false);
            stream.onTerminated = expectAsync1((errorCode) {
              expect(errorCode, 8);
            }, count: 1);
            readyForError.complete();
            await client.finish();
          }

          await Future.wait([serverFun(), clientFun()]);
        });

    group('flow-control', () {
      const int kChunkSize = 1024;
      const int kNumberOfMessages = 1000;
      final headers = [new Header.ascii('a', 'b')];


      Future testWindowSize(ClientTransportConnection client,
                            ServerTransportConnection server,
                            int expectedStreamFlowcontrolWindow) async {

        expect(expectedStreamFlowcontrolWindow,
               lessThan(kChunkSize * kNumberOfMessages));

        int serverSentBytes = 0;
        Completer flowcontrolWindowFull = new Completer();

        Future serverFun() async {
          await for (ServerTransportStream stream in server.incomingStreams) {
            stream.sendHeaders([new Header.ascii('x', 'y')]);

            int messageNr = 0;
            StreamController controller;
            addData() {
              if (!controller.isPaused) {
                if (messageNr < kNumberOfMessages) {
                  var messageBytes = new Uint8List(kChunkSize);
                  for (int j = 0; j < messageBytes.length; j++) {
                    messageBytes[j] = (messageNr + j) % 256;
                  }
                  controller.add(new DataStreamMessage(messageBytes));

                  messageNr++;
                  serverSentBytes += messageBytes.length;

                  Timer.run(addData);
                } else {
                  if (!controller.isClosed) controller.close();
                }
              }
            }

            controller = new StreamController(
                onListen: () {
                  addData();
                },
                onPause: expectAsync0(() {
                  // Assert that we're now at the place (since the granularity
                  // of adding is [kChunkSize], it could be that we added
                  // [kChunkSize - 1] bytes more than allowed, before getting
                  // the pause event).
                  expect((serverSentBytes - kChunkSize + 1),
                         lessThan(expectedStreamFlowcontrolWindow));
                  flowcontrolWindowFull.complete();
                }),
                onResume: () {
                  addData();
                },
                onCancel: () {});

            await stream.outgoingMessages.addStream(controller.stream);
            await stream.outgoingMessages.close();
            await stream.incomingMessages.toList();
          }
          await server.finish();
        }

        Future clientFun() async {
          var stream = client.makeRequest(headers, endStream: true);

          bool gotHeadersFrame = false;
          int byteNr = 0;

          var sub = stream.incomingMessages.listen((message) {
            if (!gotHeadersFrame) {
              expect(message is HeadersStreamMessage, true);
              gotHeadersFrame = true;
            } else {
              expect(message is DataStreamMessage, true);
              DataStreamMessage dataMessage = message;

              // We're just testing the first byte, to make the test faster.
              expect(dataMessage.bytes[0],
                     ((byteNr ~/ kChunkSize) + (byteNr % kChunkSize)) % 256);

              byteNr += dataMessage.bytes.length;
            }
          });

          // We pause immediately, making the server fill the stream flowcontrol
          // window.
          sub.pause();

          await flowcontrolWindowFull.future;
          sub.resume();
          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      }

      transportTest('fast-sender-receiver-paused--default-window-size',
          (ClientTransportConnection client,
           ServerTransportConnection server) async {
        await testWindowSize(client, server, new Window().size);
      });

      transportTest('fast-sender-receiver-paused--10kb-window-size',
          (ClientTransportConnection client,
           ServerTransportConnection server) async {
        await testWindowSize(client, server, 8096);
      }, clientSettings: new ClientSettings(streamWindowSize: 8096));
    });
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

