// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE FILE.

import 'dart:async';
import 'dart:typed_data';

import 'package:http2/src/flowcontrol/window.dart';
import 'package:http2/transport.dart';
import 'package:pedantic/pedantic.dart';
import 'package:test/test.dart';

import 'src/hpack/hpack_test.dart' show isHeader;

void main() {
  group('transport-test', () {
    transportTest('ping',
        (TransportConnection client, TransportConnection server) async {
      await client.ping();
      await server.ping();
    });

    transportTest('terminated-client-ping',
        (TransportConnection client, TransportConnection server) async {
      var clientError = client.ping().catchError(expectAsync2((e, s) {
        expect(e, isA<TransportException>());
      }));
      await client.terminate();
      await clientError;

      // NOTE: Now the connection is dead and client/server should complete
      // with [TransportException]s when doing work (e.g. ping).
      unawaited(client.ping().catchError(expectAsync2((e, s) {
        expect(e, isA<TransportException>());
      })));
      unawaited(server.ping().catchError(expectAsync2((e, s) {
        expect(e, isA<TransportException>());
      })));
    });

    transportTest('terminated-server-ping',
        (TransportConnection client, TransportConnection server) async {
      var clientError = client.ping().catchError(expectAsync2((e, s) {
        expect(e, isA<TransportException>());
      }));
      await server.terminate();
      await clientError;

      // NOTE: Now the connection is dead and the client/server should complete
      // with [TransportException]s when doing work (e.g. ping).
      unawaited(client.ping().catchError(expectAsync2((e, s) {
        expect(e, isA<TransportException>());
      })));
      unawaited(server.ping().catchError(expectAsync2((e, s) {
        expect(e, isA<TransportException>());
      })));
    });

    const concurrentStreamLimit = 5;
    transportTest('exhaust-concurrent-stream-limit',
        (ClientTransportConnection client,
            ServerTransportConnection server) async {
      Future clientFun() async {
        // We have to wait until the max-concurrent-streams [Setting] was
        // transferred from server to client, which is asynchronous.
        // The default is unlimited, which is why we have to wait for the server
        // setting to arrive on the client.
        // At the moment, delaying by 2 microtask cycles is enough.
        await Future.value();
        await Future.value();

        final streams = <ClientTransportStream>[];
        for (var i = 0; i < concurrentStreamLimit; ++i) {
          expect(client.isOpen, true);
          streams.add(client.makeRequest([Header.ascii('a', 'b')]));
        }
        expect(client.isOpen, false);
        for (final stream in streams) {
          stream.sendData([], endStream: true);
        }
        await client.finish();
      }

      Future serverFun() async {
        await for (final stream in server.incomingStreams) {
          await stream.incomingMessages.toList();
          stream.sendHeaders([Header.ascii('a', 'b')], endStream: true);
        }
        await server.finish();
      }

      await Future.wait([clientFun(), serverFun()]);
    },
        serverSettings:
            ServerSettings(concurrentStreamLimit: concurrentStreamLimit));

    transportTest('disabled-push', (ClientTransportConnection client,
        ServerTransportConnection server) async {
      server.incomingStreams
          .listen(expectAsync1((ServerTransportStream stream) async {
        expect(stream.canPush, false);
        expect(() => stream.push([Header.ascii('a', 'b')]),
            throwsA(const TypeMatcher<StateError>()));
        stream.sendHeaders([Header.ascii('x', 'y')], endStream: true);
      }));

      var stream =
          client.makeRequest([Header.ascii('a', 'b')], endStream: true);

      var messages = await stream.incomingMessages.toList();
      expect(messages, hasLength(1));
      expect(messages[0] is HeadersStreamMessage, true);
      expect(
          (messages[0] as HeadersStreamMessage).headers[0], isHeader('x', 'y'));

      expect(await stream.peerPushes.toList(), isEmpty);
    });

    // By default, the stream concurrency level is set to this limit.
    const kDefaultStreamLimit = 100;
    transportTest('enabled-push-100', (ClientTransportConnection client,
            ServerTransportConnection server) async {
      // To ensure the limit is kept up-to-date with closing/opening streams, we
      // retry this.
      const kRepetitions = 20;

      Future serverFun() async {
        await for (ServerTransportStream stream in server.incomingStreams) {
          var pushes = <ServerTransportStream>[];
          for (var i = 0; i < kDefaultStreamLimit; i++) {
            expect(stream.canPush, true);
            pushes.add(stream.push([Header.ascii('a', 'b')]));
          }

          // Now we should have reached the limit and we should not be able to
          // create more pushes.
          expect(stream.canPush, false);
          expect(() => stream.push([Header.ascii('a', 'b')]),
              throwsA(const TypeMatcher<StateError>()));

          // Finish the pushes
          for (var pushedStream in pushes) {
            pushedStream
                .sendHeaders([Header.ascii('e', 'nd')], endStream: true);
            await pushedStream.incomingMessages.toList();
          }

          // Finish the stream.
          stream.sendHeaders([Header.ascii('x', 'y')], endStream: true);
          expect(await stream.incomingMessages.toList(), hasLength(1));
        }
      }

      Future clientFun() async {
        for (var i = 0; i < kRepetitions; i++) {
          var stream =
              client.makeRequest([Header.ascii('a', 'b')], endStream: true);

          Future<int> expectPeerPushes() async {
            var numberOfPushes = 0;
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
    },
        clientSettings: ClientSettings(
            concurrentStreamLimit: kDefaultStreamLimit,
            allowServerPushes: true));

    transportTest('early-shutdown', (ClientTransportConnection client,
        ServerTransportConnection server) async {
      Future serverFun() async {
        await for (ServerTransportStream stream in server.incomingStreams) {
          stream.sendHeaders([Header.ascii('x', 'y')], endStream: true);
          expect(await stream.incomingMessages.toList(), hasLength(1));
        }
        await server.finish();
      }

      Future clientFun() async {
        var headers = [Header.ascii('a', 'b')];
        var stream = client.makeRequest(headers, endStream: true);
        var finishFuture = client.finish();
        var messages = await stream.incomingMessages.toList();
        expect(messages, hasLength(1));
        await finishFuture;
      }

      await Future.wait([serverFun(), clientFun()]);
    });

    transportTest('client-terminates-stream', (ClientTransportConnection client,
        ServerTransportConnection server) async {
      var readyForError = Completer();

      Future serverFun() async {
        await for (ServerTransportStream stream in server.incomingStreams) {
          stream.sendHeaders([Header.ascii('x', 'y')], endStream: true);
          stream.incomingMessages.listen(expectAsync1((msg) {
            expect(msg, isA<HeadersStreamMessage>());
            readyForError.complete();
          }), onError: expectAsync1((error) {
            expect('$error', contains('Stream was terminated by peer'));
          }));
        }
        await server.finish();
      }

      Future clientFun() async {
        var headers = [Header.ascii('a', 'b')];
        var stream = client.makeRequest(headers, endStream: false);
        await readyForError.future;
        stream.terminate();
        await client.finish();
      }

      await Future.wait([serverFun(), clientFun()]);
    });

    transportTest('server-terminates-stream', (ClientTransportConnection client,
        ServerTransportConnection server) async {
      Future serverFun() async {
        await for (ServerTransportStream stream in server.incomingStreams) {
          stream.terminate();
        }
        await server.finish();
      }

      Future clientFun() async {
        var headers = [Header.ascii('a', 'b')];
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
      var readyForError = Completer();

      Future serverFun() async {
        await for (ServerTransportStream stream in server.incomingStreams) {
          stream.onTerminated = expectAsync1((errorCode) {
            expect(errorCode, 8);
          }, count: 1);
          stream.sendHeaders([Header.ascii('x', 'y')], endStream: false);
          stream.incomingMessages.listen(
            expectAsync1((msg) {
              expect(msg, isA<HeadersStreamMessage>());
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
        var headers = [Header.ascii('a', 'b')];
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
      var readyForError = Completer();

      Future serverFun() async {
        await for (ServerTransportStream stream in server.incomingStreams) {
          stream.sendHeaders([Header.ascii('x', 'y')], endStream: false);
          stream.incomingMessages.listen(
            expectAsync1((msg) async {
              expect(msg, isA<HeadersStreamMessage>());
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
        var headers = [Header.ascii('a', 'b')];
        var stream = client.makeRequest(headers, endStream: false);
        stream.onTerminated = expectAsync1((errorCode) {
          expect(errorCode, 8);
        }, count: 1);
        readyForError.complete();
        await client.finish();
      }

      await Future.wait([serverFun(), clientFun()]);
    });

    transportTest('idle-handler', (ClientTransportConnection client,
        ServerTransportConnection server) async {
      Future serverFun() async {
        var activeCount = 0;
        var idleCount = 0;
        server.onActiveStateChanged = expectAsync1((active) {
          if (active) {
            activeCount++;
          } else {
            idleCount++;
          }
        }, count: 6);
        await for (final stream in server.incomingStreams) {
          stream.sendHeaders([]);
          unawaited(stream.incomingMessages
              .toList()
              .then((_) => stream.outgoingMessages.close()));
        }
        await server.finish();
        expect(activeCount, 3);
        expect(idleCount, 3);
      }

      Future clientFun() async {
        var activeCount = 0;
        var idleCount = 0;
        client.onActiveStateChanged = expectAsync1((active) {
          if (active) {
            activeCount++;
          } else {
            idleCount++;
          }
        }, count: 6);
        final streams = List<ClientTransportStream>.generate(
            5, (_) => client.makeRequest([]));
        await Future.wait(streams.map((s) => s.outgoingMessages.close()));
        await Future.wait(streams.map((s) => s.incomingMessages.toList()));
        // This extra await is needed to allow the idle handler to run before
        // verifying the idleCount, because the stream cleanup runs
        // asynchronously after the stream is closed.
        await Future.value();
        expect(activeCount, 1);
        expect(idleCount, 1);

        var stream = client.makeRequest([]);
        await stream.outgoingMessages.close();
        await stream.incomingMessages.toList();
        await Future.value();

        stream = client.makeRequest([]);
        await stream.outgoingMessages.close();
        await stream.incomingMessages.toList();
        await Future.value();

        await client.finish();
        expect(activeCount, 3);
        expect(idleCount, 3);
      }

      await Future.wait([clientFun(), serverFun()]);
    });

    group('flow-control', () {
      const kChunkSize = 1024;
      const kNumberOfMessages = 1000;
      final headers = [Header.ascii('a', 'b')];

      Future testWindowSize(
          ClientTransportConnection client,
          ServerTransportConnection server,
          int expectedStreamFlowcontrolWindow) async {
        expect(expectedStreamFlowcontrolWindow,
            lessThan(kChunkSize * kNumberOfMessages));

        var serverSentBytes = 0;
        var flowcontrolWindowFull = Completer();

        Future serverFun() async {
          await for (ServerTransportStream stream in server.incomingStreams) {
            stream.sendHeaders([Header.ascii('x', 'y')]);

            var messageNr = 0;
            StreamController<StreamMessage> controller;
            void addData() {
              if (!controller.isPaused) {
                if (messageNr < kNumberOfMessages) {
                  var messageBytes = Uint8List(kChunkSize);
                  for (var j = 0; j < messageBytes.length; j++) {
                    messageBytes[j] = (messageNr + j) % 256;
                  }
                  controller.add(DataStreamMessage(messageBytes));

                  messageNr++;
                  serverSentBytes += messageBytes.length;

                  Timer.run(addData);
                } else {
                  if (!controller.isClosed) controller.close();
                }
              }
            }

            controller = StreamController(
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

          var gotHeadersFrame = false;
          var byteNr = 0;

          var sub = stream.incomingMessages.listen((message) {
            if (!gotHeadersFrame) {
              expect(message, isA<HeadersStreamMessage>());
              gotHeadersFrame = true;
            } else {
              expect(message, isA<DataStreamMessage>());
              var dataMessage = message as DataStreamMessage;

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
        await testWindowSize(client, server, Window().size);
      });

      transportTest('fast-sender-receiver-paused--10kb-window-size',
          (ClientTransportConnection client,
              ServerTransportConnection server) async {
        await testWindowSize(client, server, 8096);
      }, clientSettings: ClientSettings(streamWindowSize: 8096));
    });
  });
}

void transportTest(
    String name,
    Future<void> Function(ClientTransportConnection, ServerTransportConnection)
        func,
    {ClientSettings clientSettings,
    ServerSettings serverSettings}) {
  return test(name, () {
    var bidirectional = BidirectionalConnection();
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

  final StreamController<List<int>> writeA = StreamController();
  final StreamController<List<int>> writeB = StreamController();
  Stream<List<int>> get readA => writeA.stream;
  Stream<List<int>> get readB => writeB.stream;

  ClientTransportConnection get clientConnection =>
      ClientTransportConnection.viaStreams(readA, writeB.sink,
          settings: clientSettings);

  ServerTransportConnection get serverConnection =>
      ServerTransportConnection.viaStreams(readB, writeA.sink,
          settings: serverSettings);
}
