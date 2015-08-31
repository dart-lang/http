// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/ping/ping_handler.dart';

import '../error_matchers.dart';
import '../mock_utils.dart';

main() {
  group('ping-handler', () {
    test('successful-ping', () async {
      var writer = new FrameWriterMock();
      var pingHandler = new PingHandler(writer);
      var tc = new TestCounter(count: 2);

      int pingCount = 1;
      writer.mock_writePingFrame = (int opaqueData, {bool ack: false}) {
        expect(opaqueData, pingCount);
        expect(ack, false);
        pingCount++;
        tc.got();
      };

      Future p1 = pingHandler.ping();
      Future p2 = pingHandler.ping();

      var header = new FrameHeader(8, FrameType.PING, PingFrame.FLAG_ACK, 0);
      pingHandler.processPingFrame(new PingFrame(header, 1));
      var header2 = new FrameHeader(8, FrameType.PING, PingFrame.FLAG_ACK, 0);
      pingHandler.processPingFrame(new PingFrame(header2, 2));

      await p1;
      await p2;
    });

    test('successful-ack-to-remote-ping', () async {
      var writer = new FrameWriterMock();
      var pingHandler = new PingHandler(writer);
      var tc = new TestCounter(count: 2);

      int pingCount = 1;
      writer.mock_writePingFrame = (int opaqueData, {bool ack: false}) {
        expect(opaqueData, pingCount);
        expect(ack, true);
        pingCount++;
        tc.got();
      };

      var header = new FrameHeader(8, FrameType.PING, 0, 0);
      pingHandler.processPingFrame(new PingFrame(header, 1));
      var header2 = new FrameHeader(8, FrameType.PING, 0, 0);
      pingHandler.processPingFrame(new PingFrame(header2, 2));
    });

    test('ping-unknown-opaque-data', () async {
      var writer = new FrameWriterMock();
      var pingHandler = new PingHandler(writer);
      var tc = new TestCounter();

      writer.mock_writePingFrame = (int opaqueData, {bool ack: false}) {
        expect(opaqueData, 1);
        tc.got();
      };

      Future future = pingHandler.ping();

      var header = new FrameHeader(8, FrameType.PING, PingFrame.FLAG_ACK, 0);
      expect(() => pingHandler.processPingFrame(new PingFrame(header, 2)),
             throwsProtocolException);

      // Ensure outstanding pings will be completed with an error once we call
      // `pingHandler.terminate()`.
      future.catchError(expectAsync((error, _) {
        expect(error, 'hello world');
      }));
      pingHandler.terminate('hello world');
    });

    test('terminate-ping-handler', () async {
      var writer = new FrameWriterMock();
      var pingHandler = new PingHandler(writer);

      pingHandler.terminate('hello world');
      expect(() => pingHandler.processPingFrame(null),
             throwsTerminatedException);
      expect(pingHandler.ping(),
             throwsTerminatedException);
    });

    test('ping-non-zero-stream-id', () async {
      var writer = new FrameWriterMock();
      var pingHandler = new PingHandler(writer);

      var header = new FrameHeader(8, FrameType.PING, PingFrame.FLAG_ACK, 1);
      expect(() => pingHandler.processPingFrame(new PingFrame(header, 1)),
             throwsProtocolException);
    });
  });
}

class FrameWriterMock extends SmartMock implements FrameWriter {
  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}
