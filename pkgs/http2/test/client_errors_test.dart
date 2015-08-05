// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.test.client_errors_test;

import 'dart:async';
import 'dart:convert';

import 'package:unittest/unittest.dart';

import 'package:http2/transport.dart';
import 'package:http2/src/connection_preface.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/hpack/hpack.dart';
import 'package:http2/src/settings/settings.dart';

main() {
  group('client-errors', () {
    clientErrorTest('no-settings-frame-at-beginning',
        (ServerTransportConnection server,
         FrameWriter clientWriter,
         StreamIterator<Frame> clientReader,
         Future<Frame> nextFrame()) async {

      Future serverFun() async {
        // Make sure the server reports the connection error on the stream of
        // incoming connections.
        await server.incomingStreams.toList().catchError(expectAsync((error) {
          expect('$error', contains('Connection error'));
        }));

        await server.terminate();
      }

      Future clientFun() async {
        expect(await nextFrame() is SettingsFrame, true);

        // Write headers frame to open a new stream
        clientWriter.writeHeadersFrame(1, [], endStream: true);

        // Make sure the client gets a [GoawayFrame] frame.
        var frame = await nextFrame();
        expect(frame is GoawayFrame, true);
        expect((frame as GoawayFrame).errorCode, ErrorCode.PROTOCOL_ERROR);

        // Make sure the server ended the connection.
        expect(await clientReader.moveNext(), false);
      }

      await Future.wait([serverFun(), clientFun()]);
    });
  });
}

clientErrorTest(String name,
                func(serverConnection, frameWriter, frameReader, readNext)) {
  return test(name, () {
    var streams = new ClientErrorStreams();
    var clientReader = streams.clientConnectionFrameReader;

    Future<Frame> readNext() async {
      expect(await clientReader.moveNext(), true);
      return clientReader.current;
    }

    return func(streams.serverConnection,
                streams.clientConnectionFrameWriter,
                clientReader,
                readNext);
  });
}

class ClientErrorStreams {
  final StreamController<List<int>> writeA = new StreamController();
  final StreamController<List<int>> writeB = new StreamController();
  Stream<List<int>> get readA => writeA.stream;
  Stream<List<int>> get readB => writeB.stream;

  StreamIterator<Frame> get clientConnectionFrameReader {
    Settings localSettings = new Settings();
    return new StreamIterator(
        new FrameReader(readA, localSettings).startDecoding());
  }

  FrameWriter get clientConnectionFrameWriter {
    var encoder = new HPackEncoder();
    Settings peerSettings = new Settings();
    writeB.add(CONNECTION_PREFACE);
    return new FrameWriter(encoder, writeB, peerSettings);
  }

  ServerTransportConnection get serverConnection
      => new ServerTransportConnection.viaStreams(readB, writeA);
}
