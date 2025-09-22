// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show ascii;
import 'dart:typed_data';

import 'package:http2/src/connection_preface.dart';
import 'package:http2/src/flowcontrol/window.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/hpack/hpack.dart';
import 'package:http2/src/settings/settings.dart';
import 'package:http2/transport.dart';
import 'package:test/test.dart';

import 'src/hpack/hpack_test.dart' show isHeader;

void main() {
  group('client-tests', () {
    group('normal', () {
      clientTest('gracefull-shutdown-for-unused-connection', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        var settingsDone = Completer<void>();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame(), isA<SettingsFrame>());

          settingsDone.complete();

          // Make sure we get the graceful shutdown message.
          expect(
            await nextFrame(),
            isA<GoawayFrame>().having(
              (f) => f.errorCode,
              'errorCode',
              ErrorCode.NO_ERROR,
            ),
          );

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

    group('connection-operational', () {
      clientTest('on-connection-operational-fires', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        final settingsDone = Completer<void>();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          settingsDone.complete();
          expect(await nextFrame(), isA<SettingsFrame>());
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame(), isA<SettingsFrame>());

          // Make sure we get the graceful shutdown message.
          expect(
            await nextFrame(),
            isA<GoawayFrame>().having(
              (f) => f.errorCode,
              'errorCode',
              ErrorCode.NO_ERROR,
            ),
          );

          // Make sure the client ended the connection.
          expect(await serverReader.moveNext(), false);
        }

        Future clientFun() async {
          await settingsDone.future;
          await client.onInitialPeerSettingsReceived.timeout(
            const Duration(milliseconds: 20),
          ); // Should complete

          expect(client.isOpen, true);

          // Try to gracefully finish the connection.
          var future = client.finish();

          expect(client.isOpen, false);

          await future;
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('on-connection-operational-does-not-fire', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        final goawayReceived = Completer<void>();
        Future serverFun() async {
          serverWriter.writePingFrame(42);
          expect(await nextFrame(), isA<SettingsFrame>());
          expect(await nextFrame(), isA<GoawayFrame>());
          goawayReceived.complete();
          expect(await serverReader.moveNext(), false);
        }

        Future clientFun() async {
          expect(client.isOpen, true);

          expect(
            client.onInitialPeerSettingsReceived.timeout(
              const Duration(seconds: 1),
            ),
            throwsA(isA<TimeoutException>()),
          );

          // We wait until the server received the error (it's actually later
          // than necessary, but we can't make a deterministic test otherwise).
          await goawayReceived.future;

          expect(client.isOpen, false);

          String? error;
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
    });

    group('server-errors', () {
      clientTest('no-settings-frame-at-beginning-immediate-error', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        var goawayReceived = Completer<void>();
        Future serverFun() async {
          serverWriter.writePingFrame(42);
          expect(await nextFrame(), isA<SettingsFrame>());
          expect(await nextFrame(), isA<GoawayFrame>());
          goawayReceived.complete();
          expect(await serverReader.moveNext(), false);
        }

        Future clientFun() async {
          expect(client.isOpen, true);

          // We wait until the server received the error (it's actually later
          // than necessary, but we can't make a deterministic test otherwise).
          await goawayReceived.future;

          expect(client.isOpen, false);

          String? error;
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

      clientTest('no-settings-frame-at-beginning-delayed-error', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        Future serverFun() async {
          expect(await nextFrame(), isA<SettingsFrame>());
          expect(await nextFrame(), isA<HeadersFrame>());
          serverWriter.writePingFrame(42);
          expect(await nextFrame(), isA<GoawayFrame>());
          expect(await serverReader.moveNext(), false);
        }

        Future clientFun() async {
          expect(client.isOpen, true);
          var stream = client.makeRequest([Header.ascii('a', 'b')]);

          String? error;
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

      clientTest('data-frame-for-invalid-stream', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        var handshakeCompleter = Completer<void>();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame(), isA<SettingsFrame>());

          handshakeCompleter.complete();

          var headers = await nextFrame() as HeadersFrame;
          expect(
            await nextFrame(),
            isA<DataFrame>().having(
              (p0) => p0.hasEndStreamFlag,
              'Last data frame',
              true,
            ),
          );

          // Write a data frame for a non-existent stream.
          var invalidStreamId = headers.header.streamId + 2;
          serverWriter.writeDataFrame(invalidStreamId, [42]);

          // Make sure the client sends a [RstStreamFrame] frame.
          expect(
            await nextFrame(),
            isA<WindowUpdateFrame>().having(
              (p0) => p0.header.streamId,
              'Connection update',
              0,
            ),
          );
          expect(
            await nextFrame(),
            isA<RstStreamFrame>()
                .having(
                  (f) => f.errorCode,
                  'errorCode',
                  ErrorCode.STREAM_CLOSED,
                )
                .having(
                  (f) => f.header.streamId,
                  'header.streamId',
                  invalidStreamId,
                ),
          );

          // Close the original stream.
          serverWriter.writeDataFrame(
            headers.header.streamId,
            [],
            endStream: true,
          );

          // Wait for the client finish.
          expect(await nextFrame(), isA<GoawayFrame>());
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

      clientTest('data-frame-after-stream-closed', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        var handshakeCompleter = Completer<void>();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame(), isA<SettingsFrame>());

          handshakeCompleter.complete();

          var headers = await nextFrame() as HeadersFrame;
          expect(
            await nextFrame(),
            isA<DataFrame>().having(
              (p0) => p0.hasEndStreamFlag,
              'Last data frame',
              true,
            ),
          );

          var streamId = headers.header.streamId;

          // Write a data frame for a non-existent stream.
          var data1 = [42, 42];
          serverWriter.writeDataFrame(streamId, data1, endStream: true);

          // Write more data on the closed stream.
          var data2 = [42];
          serverWriter.writeDataFrame(streamId, data2);

          // NOTE: The order of the window update frame / rst frame just
          // happens to be like that ATM.

          // The two WindowUpdateFrames for the data1 DataFrame.
          expect(
            await nextFrame(),
            isA<WindowUpdateFrame>()
                .having((p0) => p0.header.streamId, 'Stream update', 1)
                .having(
                  (p0) => p0.windowSizeIncrement,
                  'Windowsize',
                  data1.length,
                ),
          );

          expect(
            await nextFrame(),
            isA<WindowUpdateFrame>()
                .having((p0) => p0.header.streamId, 'Connection update', 0)
                .having(
                  (p0) => p0.windowSizeIncrement,
                  'Windowsize',
                  data1.length,
                ),
          );

          // The [WindowUpdateFrame] for the frame on the closed stream, which
          // should still update the connection.
          expect(
            await nextFrame(),
            isA<WindowUpdateFrame>()
                .having((p0) => p0.header.streamId, 'Connection update', 0)
                .having(
                  (p0) => p0.windowSizeIncrement,
                  'Windowsize',
                  data2.length,
                ),
          );

          // Make sure we get a [RstStreamFrame] frame.
          expect(
            await nextFrame(),
            isA<RstStreamFrame>()
                .having(
                  (f) => f.errorCode,
                  'errorCode',
                  ErrorCode.STREAM_CLOSED,
                )
                .having((f) => f.header.streamId, 'header.streamId', streamId),
          );

          // Wait for the client finish.
          expect(await nextFrame(), isA<GoawayFrame>());
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([Header.ascii('a', 'b')]);
          await stream.outgoingMessages.close();
          var messages = await stream.incomingMessages.toList();
          expect(messages, hasLength(1));
          expect(
            messages[0],
            isA<DataStreamMessage>().having(
              (p0) => p0.bytes,
              'Same as `data1` above',
              [42, 42],
            ),
          );

          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('header-frame-received-after-stream-cancel', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        var handshakeCompleter = Completer<void>();
        var serverReceivedHeaders = Completer<void>();
        var cancelDone = Completer<void>();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame(), isA<SettingsFrame>());

          handshakeCompleter.complete();

          var headers1 = await nextFrame() as HeadersFrame;
          var streamId1 = headers1.header.streamId;
          expect(
            await nextFrame(),
            isA<DataFrame>().having(
              (p0) => p0.hasEndStreamFlag,
              'Last data frame',
              true,
            ),
          );

          var headers2 = await nextFrame() as HeadersFrame;
          var streamId2 = headers2.header.streamId;
          expect(
            await nextFrame(),
            isA<DataFrame>().having(
              (p0) => p0.hasEndStreamFlag,
              'Last data frame',
              true,
            ),
          );

          serverReceivedHeaders.complete();
          await cancelDone.future;
          expect(
            await nextFrame(),
            isA<RstStreamFrame>().having(
              (f) => f.header.streamId,
              'header.streamId',
              streamId1,
            ),
          );

          // Client has canceled, but we already had a response going out over
          // the wire...
          serverWriter.writeHeadersFrame(streamId1, [Header.ascii('e', 'f')]);
          // Client will send an extra [RstStreamFrame] in response to this
          // unexpected header. That's not required, but it is current
          // behavior, so advance past it.
          expect(
            await nextFrame(),
            isA<RstStreamFrame>().having(
              (f) => f.header.streamId,
              'header.streamId',
              streamId1,
            ),
          );

          // Respond on the second stream.
          var data2 = [43];
          serverWriter.writeDataFrame(streamId2, data2, endStream: true);
          serverWriter.writeRstStreamFrame(streamId2, ErrorCode.STREAM_CLOSED);

          // The two WindowUpdateFrames for the data2 DataFrame.
          expect(
            await nextFrame(),
            isA<WindowUpdateFrame>().having(
              (p0) => p0.header.streamId,
              'Stream update',
              streamId2,
            ),
          );
          expect(
            await nextFrame(),
            isA<WindowUpdateFrame>().having(
              (p0) => p0.header.streamId,
              'Connection update',
              0,
            ),
          );

          expect(await nextFrame(), isA<GoawayFrame>());
          expect(await serverReader.moveNext(), false);

          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          // First stream: we'll send data and then cancel quickly, but the
          // server will already have a response in flight.
          var stream1 = client.makeRequest([Header.ascii('a', 'b')]);
          await stream1.outgoingMessages.close();

          // Second stream: server will respond only after we've canceled the
          // first stream.
          var stream2 = client.makeRequest([Header.ascii('c', 'd')]);
          await stream2.outgoingMessages.close();

          await serverReceivedHeaders.future;
          stream1.terminate();
          cancelDone.complete();

          var messages2 = await stream2.incomingMessages.toList();
          expect(messages2, hasLength(1));
          var message2 = messages2[0];
          expect(
            message2,
            isA<DataStreamMessage>().having(
              (p0) => p0.bytes,
              'Same as `data2` above',
              [43],
            ),
          );

          expect(client.isOpen, true);
          var future = client.finish();
          expect(client.isOpen, false);
          await future;
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('data-frame-received-after-stream-cancel', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        var handshakeCompleter = Completer<void>();
        var cancelDone = Completer<void>();
        var endDone = Completer<void>();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame(), isA<SettingsFrame>());

          handshakeCompleter.complete();

          var headers = await nextFrame() as HeadersFrame;
          expect(
            await nextFrame(),
            isA<DataFrame>().having(
              (p0) => p0.hasEndStreamFlag,
              'Last data frame',
              true,
            ),
          );
          var streamId = headers.header.streamId;

          // Write a data frame.
          serverWriter.writeDataFrame(streamId, [42]);
          await cancelDone.future;
          serverWriter.writeDataFrame(streamId, [43]);

          // NOTE: The order of the window update frame / rst frame just
          // happens to be like that ATM.

          // Await stream/connection window update frame.
          expect(
            await nextFrame(),
            isA<WindowUpdateFrame>()
                .having((p0) => p0.header.streamId, 'Stream update', 1)
                .having((p0) => p0.windowSizeIncrement, 'Windowsize', 1),
          );
          expect(
            await nextFrame(),
            isA<WindowUpdateFrame>()
                .having((p0) => p0.header.streamId, 'Connection update', 0)
                .having((p0) => p0.windowSizeIncrement, 'Windowsize', 1),
          );
          expect(
            await nextFrame(),
            isA<WindowUpdateFrame>()
                .having((p0) => p0.header.streamId, 'Connection update', 0)
                .having((p0) => p0.windowSizeIncrement, 'Windowsize', 1),
          );

          // Make sure we get a [RstStreamFrame] frame.
          expect(
            await nextFrame(),
            isA<RstStreamFrame>()
                .having((f) => f.errorCode, 'errorCode', ErrorCode.CANCEL)
                .having((f) => f.header.streamId, 'header.streamId', streamId),
          );

          serverWriter.writeRstStreamFrame(streamId, ErrorCode.STREAM_CLOSED);

          endDone.complete();

          // Wait for the client finish.
          expect(await nextFrame(), isA<GoawayFrame>());
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([Header.ascii('a', 'b')]);
          await stream.outgoingMessages.close();

          // first will cancel the stream
          var message = await stream.incomingMessages.first;
          expect(
            message,
            isA<DataStreamMessage>().having(
              (p0) => p0.bytes,
              'Same sent data above',
              [42],
            ),
          );

          cancelDone.complete();

          await endDone.future;
          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('data-frame-received-after-stream-cancel-and-out-not-closed', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        var handshakeCompleter = Completer<void>();
        var cancelDone = Completer<void>();
        var endDone = Completer<void>();
        var clientDone = Completer<void>();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame(), isA<SettingsFrame>());

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

          expect(
            await nextFrame(),
            isA<WindowUpdateFrame>()
                .having((p0) => p0.header.streamId, 'Stream update', 1)
                .having((p0) => p0.windowSizeIncrement, 'Windowsize', 1),
          );
          expect(
            await nextFrame(),
            isA<WindowUpdateFrame>()
                .having((p0) => p0.header.streamId, 'Connection update', 0)
                .having((p0) => p0.windowSizeIncrement, 'Windowsize', 1),
          );
          expect(
            await nextFrame(),
            isA<WindowUpdateFrame>()
                .having((p0) => p0.header.streamId, 'Connection update', 0)
                .having((p0) => p0.windowSizeIncrement, 'Windowsize', 1),
          );

          await clientDone.future;
          expect(
            await nextFrame(),
            isA<DataFrame>().having(
              (p0) => p0.hasEndStreamFlag,
              'Last data frame',
              true,
            ),
          );

          // Wait for the client finish.
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([Header.ascii('a', 'b')]);

          // first will cancel the stream
          var message = await stream.incomingMessages.first;
          expect(
            message,
            isA<DataStreamMessage>().having(
              (p0) => p0.bytes,
              'Same sent data above',
              [42],
            ),
          );

          cancelDone.complete();

          await endDone.future;

          await stream.outgoingMessages.close();
          clientDone.complete();

          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('client-reports-connection-error-on-push-to-nonexistent', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        var handshakeCompleter = Completer<void>();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame(), isA<SettingsFrame>());

          handshakeCompleter.complete();

          var headers = await nextFrame() as HeadersFrame;
          expect(
            await nextFrame(),
            isA<DataFrame>().having(
              (p0) => p0.hasEndStreamFlag,
              'Last data frame',
              true,
            ),
          );

          var streamId = headers.header.streamId;

          // Write response.
          serverWriter.writeHeadersFrame(streamId, [
            Header.ascii('a', 'b'),
          ], endStream: true);

          // Push stream to the (non existing) one.
          var pushStreamId = 2;
          serverWriter.writePushPromiseFrame(streamId, pushStreamId, [
            Header.ascii('a', 'b'),
          ]);

          // Make sure we get a connection error.
          var frame = await nextFrame() as GoawayFrame;
          expect(
            ascii.decode(frame.debugData),
            contains('Cannot push on a non-existent stream'),
          );
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([Header.ascii('a', 'b')]);
          await stream.outgoingMessages.close();
          var messages = await stream.incomingMessages.toList();
          expect(messages, hasLength(1));

          expect(
            messages[0],
            isA<HeadersStreamMessage>().having(
              (p0) => p0.headers.first,
              'Same sent headers above',
              isHeader('a', 'b'),
            ),
          );

          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('client-reports-connection-error-on-push-to-non-open', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        var handshakeCompleter = Completer<void>();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame(), isA<SettingsFrame>());

          handshakeCompleter.complete();

          var headers = await nextFrame() as HeadersFrame;
          var streamId = headers.header.streamId;

          // Write response.
          serverWriter.writeDataFrame(streamId, [], endStream: true);

          // Push stream onto the existing (but half-closed) one.
          var pushStreamId = 2;
          serverWriter.writePushPromiseFrame(streamId, pushStreamId, [
            Header.ascii('a', 'b'),
          ]);

          // Make sure we get a connection error.
          var frame = await nextFrame() as GoawayFrame;
          expect(
            ascii.decode(frame.debugData),
            contains('Expected open state (was: StreamState.HalfClosedRemote)'),
          );
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

      clientTest('client-reports-flowcontrol-error-on-negative-window', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        var handshakeCompleter = Completer<void>();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame(), isA<SettingsFrame>());

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
            contains(
              'Connection level flow control window became '
              'negative.',
            ),
          );
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([Header.ascii('a', 'b')]);
          var sub = stream.incomingMessages.listen(
            expectAsync1((StreamMessage msg) {}, count: 0),
            onError: expectAsync1((Object error) {}),
          );
          sub.pause();
          await Future<void>.delayed(const Duration(milliseconds: 40));
          sub.resume();

          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });
    });

    group('client-errors', () {
      clientTest('client-resets-stream', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        var settingsDone = Completer<void>();
        var headersDone = Completer<void>();

        Future serverFun() async {
          var decoder = HPackDecoder();

          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame(), isA<SettingsFrame>());

          settingsDone.complete();

          // Make sure we got the new stream.
          var frame = await nextFrame() as HeadersFrame;
          expect(frame.hasEndStreamFlag, false);
          var decodedHeaders = decoder.decode(frame.headerBlockFragment);
          expect(decodedHeaders, hasLength(1));
          expect(decodedHeaders[0], isHeader('a', 'b'));

          headersDone.complete();

          // Make sure we got the stream reset.
          expect(
            await nextFrame(),
            isA<RstStreamFrame>().having(
              (p0) => p0.errorCode,
              'Stream reset',
              ErrorCode.CANCEL,
            ),
          );

          // Make sure we get the graceful shutdown message.
          expect(
            await nextFrame(),
            isA<GoawayFrame>().having(
              (p0) => p0.errorCode,
              'Stream reset',
              ErrorCode.NO_ERROR,
            ),
          );

          // Make sure the client ended the connection.
          expect(await serverReader.moveNext(), false);
        }

        Future clientFun() async {
          await settingsDone.future;

          // Make a new stream and terminate it.
          var stream = client.makeRequest([
            Header.ascii('a', 'b'),
          ], endStream: false);

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

      clientTest('goaway-terminates-nonprocessed-streams', (
        ClientTransportConnection client,
        FrameWriter serverWriter,
        StreamIterator<Frame> serverReader,
        Future<Frame> Function() nextFrame,
      ) async {
        var settingsDone = Completer<void>();

        Future serverFun() async {
          var decoder = HPackDecoder();

          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame(), isA<SettingsFrame>());

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
          var stream = client.makeRequest([
            Header.ascii('a', 'b'),
          ], endStream: false);

          // Make sure we don't get messages/pushes on the terminated stream.
          unawaited(
            stream.incomingMessages.toList().catchError(
              expectAsync1((e) {
                expect(
                  '$e',
                  contains(
                    'This stream was not processed and can '
                    'therefore be retried',
                  ),
                );
                return <StreamMessage>[];
              }),
            ),
          );
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
  Future Function(
    ClientTransportConnection,
    FrameWriter,
    StreamIterator<Frame> frameReader,
    Future<Frame> Function() readNext,
  )
  func,
) {
  return test(name, () {
    var streams = ClientStreams();
    var serverReader = streams.serverConnectionFrameReader;

    Future<Frame> readNext() async {
      expect(await serverReader.moveNext(), true);
      return serverReader.current;
    }

    return func(
      streams.clientConnection,
      streams.serverConnectionFrameWriter,
      serverReader,
      readNext,
    );
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
      FrameReader(streamAfterConnectionPreface, localSettings).startDecoding(),
    );
  }

  FrameWriter get serverConnectionFrameWriter {
    var encoder = HPackEncoder();
    var peerSettings = ActiveSettings();
    return FrameWriter(encoder, writeB, peerSettings);
  }

  ClientTransportConnection get clientConnection =>
      ClientTransportConnection.viaStreams(readB, writeA);
}
