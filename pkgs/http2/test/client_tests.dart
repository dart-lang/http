// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.test.client_tests;

import 'dart:async';

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

          // Try to gracefully finish the connection.
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
          HeadersFrame frame = await nextFrame();
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
    Settings localSettings = new Settings();
    var streamAfterConnectionPreface = readConnectionPreface(readA);
    return new StreamIterator(
        new FrameReader(streamAfterConnectionPreface, localSettings)
        .startDecoding());
  }

  FrameWriter get serverConnectionFrameWriter {
    var encoder = new HPackEncoder();
    Settings peerSettings = new Settings();
    return new FrameWriter(encoder, writeB, peerSettings);
  }

  ClientTransportConnection get clientConnection
      => new ClientTransportConnection.viaStreams(readB, writeA);
}
