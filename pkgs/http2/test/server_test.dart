// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import 'package:http2/transport.dart';
import 'package:http2/src/connection_preface.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/hpack/hpack.dart';
import 'package:http2/src/settings/settings.dart';

void main() {
  group('server-tests', () {
    group('normal', () {
      serverTest('gracefull-shutdown-for-unused-connection',
          (ServerTransportConnection server,
              FrameWriter clientWriter,
              StreamIterator<Frame> clientReader,
              Future<Frame> Function() nextFrame) async {
        Future serverFun() async {
          expect(await server.incomingStreams.toList(), isEmpty);
          await server.finish();
        }

        Future clientFun() async {
          expect(await nextFrame() is SettingsFrame, true);
          clientWriter.writeSettingsAckFrame();
          clientWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);

          // Tell the server to finish.
          clientWriter.writeGoawayFrame(3, ErrorCode.NO_ERROR, []);

          // Make sure the server ended the connection.
          expect(await clientReader.moveNext(), false);
        }

        await Future.wait([serverFun(), clientFun()]);
      });
    });

    group('client-errors', () {
      serverTest('no-settings-frame-at-beginning',
          (ServerTransportConnection server,
              FrameWriter clientWriter,
              StreamIterator<Frame> clientReader,
              Future<Frame> Function() nextFrame) async {
        Future serverFun() async {
          // TODO: Do we want to get an error in this case?
          expect(await server.incomingStreams.toList(), isEmpty);
          await server.finish();
        }

        Future clientFun() async {
          expect(await nextFrame() is SettingsFrame, true);

          // Write headers frame to open a new stream
          clientWriter.writeHeadersFrame(1, [], endStream: true);

          // Make sure the client gets a [GoawayFrame] frame.
          expect(
              await nextFrame(),
              isA<GoawayFrame>().having(
                  (f) => f.errorCode, 'errorCode', ErrorCode.PROTOCOL_ERROR));

          // Make sure the server ended the connection.
          expect(await clientReader.moveNext(), false);
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      serverTest('data-frame-for-invalid-stream',
          (ServerTransportConnection server,
              FrameWriter clientWriter,
              StreamIterator<Frame> clientReader,
              Future<Frame> Function() nextFrame) async {
        Future serverFun() async {
          await server.incomingStreams.toList();
          await server.finish();
        }

        Future clientFun() async {
          expect(await nextFrame() is SettingsFrame, true);
          clientWriter.writeSettingsAckFrame();
          clientWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);

          // Write data frame to non-existent stream.
          clientWriter.writeDataFrame(3, [1, 2, 3]);

          // Make sure the client gets a [RstStreamFrame] frame.
          expect(
              await nextFrame(),
              isA<RstStreamFrame>()
                  .having(
                      (f) => f.errorCode, 'errorCode', ErrorCode.STREAM_CLOSED)
                  .having((f) => f.header.streamId, 'header.streamId', 3));

          // Tell the server to finish.
          clientWriter.writeGoawayFrame(3, ErrorCode.NO_ERROR, []);

          // Make sure the server ended the connection.
          expect(await clientReader.moveNext(), false);
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      serverTest('data-frame-after-stream-closed',
          (ServerTransportConnection server,
              FrameWriter clientWriter,
              StreamIterator<Frame> clientReader,
              Future<Frame> Function() nextFrame) async {
        Future serverFun() async {
          await server.incomingStreams.toList();
          await server.finish();
        }

        Future clientFun() async {
          expect(await nextFrame() is SettingsFrame, true);
          clientWriter.writeSettingsAckFrame();
          clientWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);

          clientWriter.writeHeadersFrame(3, [Header.ascii('a', 'b')],
              endStream: true);

          // Write data frame to non-existent stream (stream 3 was closed
          // above).
          clientWriter.writeDataFrame(3, [1, 2, 3]);

          // Make sure the client gets a [RstStreamFrame] frame.
          expect(
              await nextFrame(),
              isA<RstStreamFrame>()
                  .having(
                      (f) => f.errorCode, 'errorCode', ErrorCode.STREAM_CLOSED)
                  .having((f) => f.header.streamId, 'header.streamId', 3));

          // Tell the server to finish.
          clientWriter.writeGoawayFrame(3, ErrorCode.NO_ERROR, []);

          // Make sure the server ended the connection.
          expect(await clientReader.moveNext(), false);
        }

        await Future.wait([serverFun(), clientFun()]);
      });
    });

    group('server-errors', () {
      serverTest('server-resets-stream', (ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame) async {
        Future serverFun() async {
          var it = StreamIterator(server.incomingStreams);
          expect(await it.moveNext(), true);

          TransportStream stream = it.current;
          stream.terminate();

          expect(await it.moveNext(), false);

          await server.finish();
        }

        Future clientFun() async {
          expect(await nextFrame() is SettingsFrame, true);
          clientWriter.writeSettingsAckFrame();
          clientWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);

          clientWriter.writeHeadersFrame(1, [Header.ascii('a', 'b')],
              endStream: false);

          // Make sure the client gets a [RstStreamFrame] frame.
          expect(
              await nextFrame(),
              isA<RstStreamFrame>()
                  .having((f) => f.errorCode, 'errorCode', ErrorCode.CANCEL)
                  .having((f) => f.header.streamId, 'header.streamId', 1));

          // Tell the server to finish.
          clientWriter.writeGoawayFrame(3, ErrorCode.NO_ERROR, []);

          // Make sure the server ended the connection.
          expect(await clientReader.moveNext(), false);
        }

        await Future.wait([serverFun(), clientFun()]);
      });
    });
  });
}

void serverTest(
    String name,
    void Function(
            ServerTransportConnection,
            FrameWriter,
            StreamIterator<Frame> frameReader,
            Future<Frame> Function() readNext)
        func) {
  return test(name, () {
    var streams = ClientErrorStreams();
    var clientReader = streams.clientConnectionFrameReader;

    Future<Frame> readNext() async {
      expect(await clientReader.moveNext(), true);
      return clientReader.current;
    }

    return func(streams.serverConnection, streams.clientConnectionFrameWriter,
        clientReader, readNext);
  });
}

class ClientErrorStreams {
  final StreamController<List<int>> writeA = StreamController();
  final StreamController<List<int>> writeB = StreamController();
  Stream<List<int>> get readA => writeA.stream;
  Stream<List<int>> get readB => writeB.stream;

  StreamIterator<Frame> get clientConnectionFrameReader {
    var localSettings = ActiveSettings();
    return StreamIterator(FrameReader(readA, localSettings).startDecoding());
  }

  FrameWriter get clientConnectionFrameWriter {
    var encoder = HPackEncoder();
    var peerSettings = ActiveSettings();
    writeB.add(CONNECTION_PREFACE);
    return FrameWriter(encoder, writeB, peerSettings);
  }

  ServerTransportConnection get serverConnection =>
      ServerTransportConnection.viaStreams(readB, writeA);
}
