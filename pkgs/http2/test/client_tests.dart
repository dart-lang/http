// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.test.client_tests;

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';

import 'package:http2/transport.dart';
import 'package:http2/src/connection_preface.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/hpack/hpack.dart';
import 'package:http2/src/settings/settings.dart';

import 'src/hpack/hpack_test.dart' show isHeader;

main() {
  group('client-tests', () {
    group('normal', () {
      clientTest('gracefull-shutdown-for-unused-connection',
          (ClientTransportConnection client,
           FrameWriter serverWriter,
           StreamIterator<Frame> serverReader,
           Future<Frame> nextFrame()) async {

        var settingsDone = new Completer();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          settingsDone.complete();

          // Make sure we get the graceful shutdown message.
          var frame = await nextFrame();
          expect(frame is GoawayFrame, true);
          expect((frame as GoawayFrame).errorCode, ErrorCode.NO_ERROR);

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
           Future<Frame> nextFrame()) async {

        var goawayReceived = new Completer();
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
            client.makeRequest([new Header.ascii('a', 'b')]);
          } catch (e) { error = '$e'; }
          expect(error, contains('no longer active'));

          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('no-settings-frame-at-beginning-delayed-error',
          (ClientTransportConnection client,
           FrameWriter serverWriter,
           StreamIterator<Frame> serverReader,
           Future<Frame> nextFrame()) async {

        Future serverFun() async {
          expect(await nextFrame() is SettingsFrame, true);
          expect(await nextFrame() is HeadersFrame, true);
          serverWriter.writePingFrame(42);
          expect(await nextFrame() is GoawayFrame, true);
          expect(await serverReader.moveNext(), false);
        }

        Future clientFun() async {
          expect(client.isOpen, true);
          var stream = client.makeRequest([new Header.ascii('a', 'b')]);

          var error = await stream.incomingMessages.toList()
              .catchError((e) => '$e');
          expect(error, contains('forcefully terminated'));
          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('data-frame-for-invalid-stream',
          (ClientTransportConnection client,
           FrameWriter serverWriter,
           StreamIterator<Frame> serverReader,
           Future<Frame> nextFrame()) async {

        var handshakeCompleter = new Completer();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          handshakeCompleter.complete();

          HeadersFrame headers = await nextFrame();
          DataFrame finFrame  = await nextFrame();
          expect(finFrame.hasEndStreamFlag, true);

          // Write a data frame for a non-existent stream.
          int invalidStreamId = headers.header.streamId + 2;
          serverWriter.writeDataFrame(invalidStreamId, [42]);

          // Make sure the client sends a [RstStreamFrame] frame.
          var frame = await nextFrame();
          expect(frame is RstStreamFrame, true);
          expect((frame as RstStreamFrame).errorCode, ErrorCode.STREAM_CLOSED);
          expect((frame as RstStreamFrame).header.streamId, invalidStreamId);

          // Close the original stream.
          serverWriter.writeDataFrame(
              headers.header.streamId, [], endStream: true);

          // Wait for the client finish.
          expect(await nextFrame() is GoawayFrame, true);
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([new Header.ascii('a', 'b')]);
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
           Future<Frame> nextFrame()) async {

        var handshakeCompleter = new Completer();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          handshakeCompleter.complete();

          HeadersFrame headers = await nextFrame();
          DataFrame finFrame  = await nextFrame();
          expect(finFrame.hasEndStreamFlag, true);

          int streamId = headers.header.streamId;

          // Write a data frame for a non-existent stream.
          serverWriter.writeDataFrame(streamId, [42], endStream: true);

          // Write more data on the closed stream.
          serverWriter.writeDataFrame(streamId, [42]);

          // NOTE: The order of the window update frame / rst frame just
          // happens to be like that ATM.

          // Await stream/connection window update frame.
          var win = await nextFrame();
          expect(win.header.streamId, 1);
          expect(win.windowSizeIncrement, 1);
          win = await nextFrame();
          expect(win.header.streamId, 0);
          expect(win.windowSizeIncrement, 1);

          // Make sure we get a [RstStreamFrame] frame.
          var frame = await nextFrame();
          expect(frame is RstStreamFrame, true);
          expect((frame as RstStreamFrame).errorCode, ErrorCode.STREAM_CLOSED);
          expect((frame as RstStreamFrame).header.streamId, streamId);

          // Wait for the client finish.
          expect(await nextFrame() is GoawayFrame, true);
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([new Header.ascii('a', 'b')]);
          await stream.outgoingMessages.close();
          var messages = await stream.incomingMessages.toList();
          expect(messages, hasLength(1));
          expect((messages[0] as DataStreamMessage).bytes, [42]);

          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      clientTest('client-reports-connection-error-on-push-to-nonexistent',
          (ClientTransportConnection client,
           FrameWriter serverWriter,
           StreamIterator<Frame> serverReader,
           Future<Frame> nextFrame()) async {

        var handshakeCompleter = new Completer();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          handshakeCompleter.complete();

          HeadersFrame headers = await nextFrame();
          DataFrame finFrame  = await nextFrame();
          expect(finFrame.hasEndStreamFlag, true);

          int streamId = headers.header.streamId;

          // Write response.
          serverWriter.writeHeadersFrame(
              streamId, [new Header.ascii('a', 'b')], endStream: true);

          // Push stream to the (non existing) one.
          int pushStreamId = 2;
          serverWriter.writePushPromiseFrame(
              streamId, pushStreamId, [new Header.ascii('a', 'b')]);

          // Make sure we get a connection error.
          GoawayFrame frame = await nextFrame();
          expect(ASCII.decode(frame.debugData),
                 contains('Cannot push on a non-existent stream'));
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([new Header.ascii('a', 'b')]);
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
           Future<Frame> nextFrame()) async {

        var handshakeCompleter = new Completer();

        Future serverFun() async {
          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          handshakeCompleter.complete();

          HeadersFrame headers = await nextFrame();
          int streamId = headers.header.streamId;

          // Write response.
          serverWriter.writeDataFrame(streamId, [], endStream: true);

          // Push stream onto the existing (but half-closed) one.
          int pushStreamId = 2;
          serverWriter.writePushPromiseFrame(
              streamId, pushStreamId, [new Header.ascii('a', 'b')]);

          // Make sure we get a connection error.
          GoawayFrame frame = await nextFrame();
          expect(ASCII.decode(frame.debugData),
          contains('Expected open state (was: StreamState.HalfClosedRemote)'));
          expect(await serverReader.moveNext(), false);
          await serverWriter.close();
        }

        Future clientFun() async {
          await handshakeCompleter.future;

          var stream = client.makeRequest([new Header.ascii('a', 'b')]);

          // NOTE: We are not closing the outgoing part on purpose.
          expect(await stream.incomingMessages.toList(), isEmpty);
          expect(await stream.peerPushes.toList(), isEmpty);

          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });
    });

    group('client-errors', () {
      clientTest('client-resets-stream',
          (ClientTransportConnection client,
           FrameWriter serverWriter,
           StreamIterator<Frame> serverReader,
           Future<Frame> nextFrame()) async {

        var settingsDone = new Completer();

        Future serverFun() async {
          var decoder = new HPackDecoder();

          serverWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);
          serverWriter.writeSettingsAckFrame();
          expect(await nextFrame() is SettingsFrame, true);

          settingsDone.complete();

          // Make sure we got the new stream.
          var frame = await nextFrame();
          expect(frame.hasEndStreamFlag, false);
          var decodedHeaders = decoder.decode(frame.headerBlockFragment);
          expect(decodedHeaders, hasLength(1));
          expect(decodedHeaders[0], isHeader('a', 'b'));

          // Make sure we got the stream reset.
          frame = await nextFrame();
          expect(frame is RstStreamFrame, true);
          expect((frame as RstStreamFrame).errorCode, ErrorCode.CANCEL);

          // Make sure we get the graceful shutdown message.
          frame = await nextFrame();
          expect(frame is GoawayFrame, true);
          expect((frame as GoawayFrame).errorCode, ErrorCode.NO_ERROR);

          // Make sure the client ended the connection.
          expect(await serverReader.moveNext(), false);
        }

        Future clientFun() async {
          await settingsDone.future;

          // Make a new stream and terminate it.
          var stream = client.makeRequest(
              [new Header.ascii('a', 'b')], endStream: false);
          stream.terminate();

          // Make sure we don't get messages/pushes on the terminated stream.
          expect(await stream.incomingMessages.toList(), isEmpty);
          expect(await stream.peerPushes.toList(), isEmpty);

          // Try to gracefully finish the connection.
          await client.finish();
        }

        await Future.wait([serverFun(), clientFun()]);
      });
    });
  });
}

clientTest(String name,
           func(clientConnection, frameWriter, frameReader, readNext)) {
  return test(name, () {
    var streams = new ClientStreams();
    var serverReader = streams.serverConnectionFrameReader;

    Future<Frame> readNext() async {
      expect(await serverReader.moveNext(), true);
      return serverReader.current;
    }

    return func(streams.clientConnection,
                streams.serverConnectionFrameWriter,
                serverReader,
                readNext);
  });
}

class ClientStreams {
  final StreamController<List<int>> writeA = new StreamController();
  final StreamController<List<int>> writeB = new StreamController();
  Stream<List<int>> get readA => writeA.stream;
  Stream<List<int>> get readB => writeB.stream;

  StreamIterator<Frame> get serverConnectionFrameReader {
    ActiveSettings localSettings = new ActiveSettings();
    var streamAfterConnectionPreface = readConnectionPreface(readA);
    return new StreamIterator(
        new FrameReader(streamAfterConnectionPreface, localSettings)
        .startDecoding());
  }

  FrameWriter get serverConnectionFrameWriter {
    var encoder = new HPackEncoder();
    ActiveSettings peerSettings = new ActiveSettings();
    return new FrameWriter(encoder, writeB, peerSettings);
  }

  ClientTransportConnection get clientConnection
      => new ClientTransportConnection.viaStreams(readB, writeA);
}
