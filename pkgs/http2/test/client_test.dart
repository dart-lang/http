// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show ascii;
import 'dart:typed_data';

import 'package:pedantic/pedantic.dart';
import 'package:test/test.dart';

import 'package:http2/src/connection_preface.dart';
import 'package:http2/src/flowcontrol/window.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/hpack/hpack.dart';
import 'package:http2/src/settings/settings.dart';
import 'package:http2/transport.dart';

import 'src/hpack/hpack_test.dart' show isHeader;

void main() {
  group('client-tests', () {
    group('normal', () {
      clientTest('gracefull-shutdown-for-unused-connection',
          (ClientTransportConnection client,
              FrameWriter serverWriter,
              StreamIterator<Frame> serverReader,
              Future<Frame> Function() nextFrame) async {
        var settingsDone = Completer();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          settingsDone.complete();

          // Make sure we get the graceful shutdown message.
          expect(
              await nextFrame(),
              isA<GoawayFrame>()
                  .having((f) => f.errorCode, 'errorCode', ErrorCode.NO_ERROR));

          // Make sure the client ended the connection.
          expect(await serverReader.moveNext(), false);
        }

        Future clientFun() async {
          await settingsDone.future;

          expect(client.isOpen, true);

          // Try to gracefully finish the connection.
          var future = client.finish();

          expect(client.isOpen, false);

          await future;
        }

        await Future.wait([serverFun(), clientFun()]);
      });
    });

    group('server-errors', () {
      clientTest('no-settings-frame-at-beginning-immediate-error',
          (ClientTransportConnection client,
              FrameWriter serverWriter,
              StreamIterator<Frame> serverReader,
              Future<Frame> Function() nextFrame) async {
        var goawayReceived = Completer();
        Future serverFun() async {
          serverWriter.writePingFrame(42);
          expect(await nextFrame() is SettingsFrame, true);
          expect(await nextFrame() is GoawayFrame, true);
          goawayReceived.complete();
          expect(await serverReader.moveNext(), false);
        }

        Future clientFun() async {
          expect(client.isOpen, true);

          // We wait until the server received the error (it's actually later
          // than necessary, but we can't make a deterministic test otherwise).
          await goawayReceived.future;

          expect(client.isOpen, false);

          var error;
          try {
            client.makeRequest([Header.ascii('a', 'b')]);
          } catch (e) {
            error = '$e';
          }
          expect(error, contains('no longer active'));

          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('no-settings-frame-at-beginning-delayed-error',
          (ClientTransportConnection client,
              FrameWriter serverWriter,
              StreamIterator<Frame> serverReader,
              Future<Frame> Function() nextFrame) async {
        Future serverFun() async {
          expect(await nextFrame() is SettingsFrame, true);
          expect(await nextFrame() is HeadersFrame, true);
          serverWriter.writePingFrame(42);
          expect(await nextFrame() is GoawayFrame, true);
          expect(await serverReader.moveNext(), false);
        }

        Future clientFun() async {
          expect(client.isOpen, true);
          var stream = client.makeRequest([Header.ascii('a', 'b')]);

          String error;
          try {
            await stream.incomingMessages.toList();
          } catch (e) {
            error = '$e';
          }
          expect(error, contains('forcefully terminated'));
          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('data-frame-for-invalid-stream',
          (ClientTransportConnection client,
              FrameWriter serverWriter,
              StreamIterator<Frame> serverReader,
              Future<Frame> Function() nextFrame) async {
        var handshakeCompleter = Completer();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          handshakeCompleter.complete();

          var headers = await nextFrame() as HeadersFrame;
          var finFrame = await nextFrame() as DataFrame;
          expect(finFrame.hasEndStreamFlag, true);

          // Write a data frame for a non-existent stream.
          var invalidStreamId = headers.header.streamId + 2;
          serverWriter.writeDataFrame(invalidStreamId, [42]);

          // Make sure the client sends a [RstStreamFrame] frame.
          expect(
              await nextFrame(),
              isA<RstStreamFrame>()
                  .having(
                      (f) => f.errorCode, 'errorCode', ErrorCode.STREAM_CLOSED)
                  .having((f) => f.header.streamId, 'header.streamId',
                      invalidStreamId));

          // Close the original stream.
          serverWriter.writeDataFrame(headers.header.streamId, [],
              endStream: true);

          // Wait for the client finish.
          expect(await nextFrame() is GoawayFrame, true);
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([Header.ascii('a', 'b')]);
          await stream.outgoingMessages.close();
          expect(await stream.incomingMessages.toList(), isEmpty);

          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('data-frame-after-stream-closed',
          (ClientTransportConnection client,
              FrameWriter serverWriter,
              StreamIterator<Frame> serverReader,
              Future<Frame> Function() nextFrame) async {
        var handshakeCompleter = Completer();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          handshakeCompleter.complete();

          var headers = await nextFrame() as HeadersFrame;
          var finFrame = await nextFrame() as DataFrame;
          expect(finFrame.hasEndStreamFlag, true);

          var streamId = headers.header.streamId;

          // Write a data frame for a non-existent stream.
          serverWriter.writeDataFrame(streamId, [42], endStream: true);

          // Write more data on the closed stream.
          serverWriter.writeDataFrame(streamId, [42]);

          // NOTE: The order of the window update frame / rst frame just
          // happens to be like that ATM.

          // Await stream/connection window update frame.
          var win = await nextFrame() as WindowUpdateFrame;
          expect(win.header.streamId, 1);
          expect(win.windowSizeIncrement, 1);
          win = await nextFrame() as WindowUpdateFrame;
          expect(win.header.streamId, 0);
          expect(win.windowSizeIncrement, 1);

          // Make sure we get a [RstStreamFrame] frame.
          expect(
              await nextFrame(),
              isA<RstStreamFrame>()
                  .having(
                      (f) => f.errorCode, 'errorCode', ErrorCode.STREAM_CLOSED)
                  .having(
                      (f) => f.header.streamId, 'header.streamId', streamId));

          // Wait for the client finish.
          expect(await nextFrame() is GoawayFrame, true);
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([Header.ascii('a', 'b')]);
          await stream.outgoingMessages.close();
          var messages = await stream.incomingMessages.toList();
          expect(messages, hasLength(1));
          expect((messages[0] as DataStreamMessage).bytes, [42]);

          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('data-frame-received-after-stream-cancel',
          (ClientTransportConnection client,
              FrameWriter serverWriter,
              StreamIterator<Frame> serverReader,
              Future<Frame> Function() nextFrame) async {
        var handshakeCompleter = Completer();
        var cancelDone = Completer();
        var endDone = Completer();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          handshakeCompleter.complete();

          var headers = await nextFrame() as HeadersFrame;
          var finFrame = await nextFrame() as DataFrame;
          expect(finFrame.hasEndStreamFlag, true);

          var streamId = headers.header.streamId;

          // Write a data frame.
          serverWriter.writeDataFrame(streamId, [42]);
          await cancelDone.future;
          serverWriter.writeDataFrame(streamId, [43]);

          // NOTE: The order of the window update frame / rst frame just
          // happens to be like that ATM.

          // Await stream/connection window update frame.
          var win = await nextFrame() as WindowUpdateFrame;
          expect(win.header.streamId, 1);
          expect(win.windowSizeIncrement, 1);
          win = await nextFrame() as WindowUpdateFrame;
          expect(win.header.streamId, 0);
          expect(win.windowSizeIncrement, 1);
          win = await nextFrame() as WindowUpdateFrame;
          expect(win.header.streamId, 0);
          expect(win.windowSizeIncrement, 1);

          // Make sure we get a [RstStreamFrame] frame.
          expect(
              await nextFrame(),
              isA<RstStreamFrame>()
                  .having((f) => f.errorCode, 'errorCode', ErrorCode.CANCEL)
                  .having(
                      (f) => f.header.streamId, 'header.streamId', streamId));

          serverWriter.writeRstStreamFrame(streamId, ErrorCode.STREAM_CLOSED);

          endDone.complete();

          // Wait for the client finish.
          expect(await nextFrame() is GoawayFrame, true);
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([Header.ascii('a', 'b')]);
          await stream.outgoingMessages.close();

          // first will cancel the stream
          var message = await stream.incomingMessages.first;
          expect((message as DataStreamMessage).bytes, [42]);
          cancelDone.complete();

          await endDone.future;
          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('data-frame-received-after-stream-cancel-and-out-not-closed',
          (ClientTransportConnection client,
              FrameWriter serverWriter,
              StreamIterator<Frame> serverReader,
              Future<Frame> Function() nextFrame) async {
        var handshakeCompleter = Completer();
        var cancelDone = Completer();
        var endDone = Completer();
        var clientDone = Completer();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          handshakeCompleter.complete();

          var headers = await nextFrame() as HeadersFrame;

          var streamId = headers.header.streamId;

          // Write a data frame.
          serverWriter.writeDataFrame(streamId, [42]);
          await cancelDone.future;
          serverWriter.writeDataFrame(streamId, [43]);
          serverWriter.writeRstStreamFrame(streamId, ErrorCode.STREAM_CLOSED);
          endDone.complete();

          // NOTE: The order of the window update frame / rst frame just
          // happens to be like that ATM.

          // Await stream/connection window update frame.
          var win = await nextFrame() as WindowUpdateFrame;
          expect(win.header.streamId, 1);
          expect(win.windowSizeIncrement, 1);
          win = await nextFrame() as WindowUpdateFrame;
          expect(win.header.streamId, 0);
          expect(win.windowSizeIncrement, 1);
          win = await nextFrame() as WindowUpdateFrame;
          expect(win.header.streamId, 0);
          expect(win.windowSizeIncrement, 1);

          await clientDone.future;
          var finFrame = await nextFrame() as DataFrame;
          expect(finFrame.hasEndStreamFlag, true);

          // Wait for the client finish.
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([Header.ascii('a', 'b')]);

          // first will cancel the stream
          var message = await stream.incomingMessages.first;
          expect((message as DataStreamMessage).bytes, [42]);
          cancelDone.complete();

          await endDone.future;

          await stream.outgoingMessages.close();
          clientDone.complete();

          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('client-reports-connection-error-on-push-to-nonexistent',
          (ClientTransportConnection client,
              FrameWriter serverWriter,
              StreamIterator<Frame> serverReader,
              Future<Frame> Function() nextFrame) async {
        var handshakeCompleter = Completer();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          handshakeCompleter.complete();

          var headers = await nextFrame() as HeadersFrame;
          var finFrame = await nextFrame() as DataFrame;
          expect(finFrame.hasEndStreamFlag, true);

          var streamId = headers.header.streamId;

          // Write response.
          serverWriter.writeHeadersFrame(streamId, [Header.ascii('a', 'b')],
              endStream: true);

          // Push stream to the (non existing) one.
          var pushStreamId = 2;
          serverWriter.writePushPromiseFrame(
              streamId, pushStreamId, [Header.ascii('a', 'b')]);

          // Make sure we get a connection error.
          var frame = await nextFrame() as GoawayFrame;
          expect(ascii.decode(frame.debugData),
              contains('Cannot push on a non-existent stream'));
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([Header.ascii('a', 'b')]);
          await stream.outgoingMessages.close();
          var messages = await stream.incomingMessages.toList();
          expect(messages, hasLength(1));
          expect((messages[0] as HeadersStreamMessage).headers.first,
              isHeader('a', 'b'));
          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('client-reports-connection-error-on-push-to-non-open',
          (ClientTransportConnection client,
              FrameWriter serverWriter,
              StreamIterator<Frame> serverReader,
              Future<Frame> Function() nextFrame) async {
        var handshakeCompleter = Completer();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          handshakeCompleter.complete();

          var headers = await nextFrame() as HeadersFrame;
          var streamId = headers.header.streamId;

          // Write response.
          serverWriter.writeDataFrame(streamId, [], endStream: true);

          // Push stream onto the existing (but half-closed) one.
          var pushStreamId = 2;
          serverWriter.writePushPromiseFrame(
              streamId, pushStreamId, [Header.ascii('a', 'b')]);

          // Make sure we get a connection error.
          var frame = await nextFrame() as GoawayFrame;
          expect(
              ascii.decode(frame.debugData),
              contains(
                  'Expected open state (was: StreamState.HalfClosedRemote)'));
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([Header.ascii('a', 'b')]);

          // NOTE: We are not closing the outgoing part on purpose.
          expect(await stream.incomingMessages.toList(), isEmpty);
          expect(await stream.peerPushes.toList(), isEmpty);

          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('client-reports-flowcontrol-error-on-negative-window',
          (ClientTransportConnection client,
              FrameWriter serverWriter,
              StreamIterator<Frame> serverReader,
              Future<Frame> Function() nextFrame) async {
        var handshakeCompleter = Completer();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          handshakeCompleter.complete();

          var headers = await nextFrame() as HeadersFrame;
          var streamId = headers.header.streamId;

          // Write more than [kFlowControlWindowSize] bytes.
          final kFlowControlWindowSize = Window().size;
          var sentBytes = 0;
          final bytes = Uint8List(1024);
          while (sentBytes <= kFlowControlWindowSize) {
            serverWriter.writeDataFrame(streamId, bytes);
            sentBytes += bytes.length;
          }

          // Read the resulting [GoawayFrame] and assert the error message
          // describes that the flow control window became negative.
          var frame = await nextFrame() as GoawayFrame;
          expect(
              ascii.decode(frame.debugData),
              contains('Connection level flow control window became '
                  'negative.'));
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([Header.ascii('a', 'b')]);
          var sub = stream.incomingMessages.listen(
              expectAsync1((StreamMessage msg) {}, count: 0),
              onError: expectAsync1((error) {}));
          sub.pause();
          await Future.delayed(const Duration(milliseconds: 40));
          sub.resume();

          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });
    });

    group('client-errors', () {
      clientTest('client-resets-stream', (ClientTransportConnection client,
          FrameWriter serverWriter,
          StreamIterator<Frame> serverReader,
          Future<Frame> Function() nextFrame) async {
        var settingsDone = Completer();
        var headersDone = Completer();

        Future serverFun() async {
          var decoder = HPackDecoder();

          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          settingsDone.complete();

          // Make sure we got the new stream.
          var frame = await nextFrame() as HeadersFrame;
          expect(frame.hasEndStreamFlag, false);
          var decodedHeaders = decoder.decode(frame.headerBlockFragment);
          expect(decodedHeaders, hasLength(1));
          expect(decodedHeaders[0], isHeader('a', 'b'));

          headersDone.complete();

          // Make sure we got the stream reset.
          var frame2 = await nextFrame() as RstStreamFrame;
          expect(frame2.errorCode, ErrorCode.CANCEL);

          // Make sure we get the graceful shutdown message.
          var frame3 = await nextFrame() as GoawayFrame;
          expect(frame3.errorCode, ErrorCode.NO_ERROR);

          // Make sure the client ended the connection.
          expect(await serverReader.moveNext(), false);
        }

        Future clientFun() async {
          await settingsDone.future;

          // Make a new stream and terminate it.
          var stream =
              client.makeRequest([Header.ascii('a', 'b')], endStream: false);

          await headersDone.future;
          stream.terminate();

          // Make sure we don't get messages/pushes on the terminated stream.
          expect(await stream.incomingMessages.toList(), isEmpty);
          expect(await stream.peerPushes.toList(), isEmpty);

          // Try to gracefully finish the connection.
          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('goaway-terminates-nonprocessed-streams',
          (ClientTransportConnection client,
              FrameWriter serverWriter,
              StreamIterator<Frame> serverReader,
              Future<Frame> Function() nextFrame) async {
        var settingsDone = Completer();

        Future serverFun() async {
          var decoder = HPackDecoder();

          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          settingsDone.complete();

          // Make sure we got the new stream.
          var frame = await nextFrame() as HeadersFrame;
          expect(frame.hasEndStreamFlag, false);
          var decodedHeaders = decoder.decode(frame.headerBlockFragment);
          expect(decodedHeaders, hasLength(1));
          expect(decodedHeaders[0], isHeader('a', 'b'));

          // Send the GoawayFrame.
          serverWriter.writeGoawayFrame(0, ErrorCode.NO_ERROR, []);

          // Since there are no open streams left, the other end should just
          // close the connection.
          expect(await serverReader.moveNext(), false);
        }

        Future clientFun() async {
          await settingsDone.future;

          // Make a new stream and terminate it.
          var stream =
              client.makeRequest([Header.ascii('a', 'b')], endStream: false);

          // Make sure we don't get messages/pushes on the terminated stream.
          unawaited(
              stream.incomingMessages.toList().catchError(expectAsync1((e) {
            expect(
                '$e',
                contains('This stream was not processed and can '
                    'therefore be retried'));
          })));
          expect(await stream.peerPushes.toList(), isEmpty);

          // Try to gracefully finish the connection.
          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });
    });
  });
}

void clientTest(
    String name,
    Future<Null> Function(
            ClientTransportConnection,
            FrameWriter,
            StreamIterator<Frame> frameReader,
            Future<Frame> Function() readNext)
        func) {
  return test(name, () {
    var streams = ClientStreams();
    var serverReader = streams.serverConnectionFrameReader;

    Future<Frame> readNext() async {
      expect(await serverReader.moveNext(), true);
      return serverReader.current;
    }

    return func(streams.clientConnection, streams.serverConnectionFrameWriter,
        serverReader, readNext);
  });
}

class ClientStreams {
  final StreamController<List<int>> writeA = StreamController();
  final StreamController<List<int>> writeB = StreamController();
  Stream<List<int>> get readA => writeA.stream;
  Stream<List<int>> get readB => writeB.stream;

  StreamIterator<Frame> get serverConnectionFrameReader {
    var localSettings = ActiveSettings();
    var streamAfterConnectionPreface = readConnectionPreface(readA);
    return StreamIterator(
        FrameReader(streamAfterConnectionPreface, localSettings)
            .startDecoding());
  }

  FrameWriter get serverConnectionFrameWriter {
    var encoder = HPackEncoder();
    var peerSettings = ActiveSettings();
    return FrameWriter(encoder, writeB, peerSettings);
  }

  ClientTransportConnection get clientConnection =>
      ClientTransportConnection.viaStreams(readB, writeA);
}
