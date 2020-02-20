// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/ping/ping_handler.dart';
import 'package:pedantic/pedantic.dart';

import '../error_matchers.dart';

void main() {
  group('ping-handler', () {
    test('successful-ping', () async {
      var writer = FrameWriterMock();
      var pingHandler = PingHandler(writer);

      var p1 = pingHandler.ping();
      var p2 = pingHandler.ping();

      verifyInOrder([
        writer.writePingFrame(1),
        writer.writePingFrame(2),
      ]);

      var header = FrameHeader(8, FrameType.PING, PingFrame.FLAG_ACK, 0);
      pingHandler.processPingFrame(PingFrame(header, 1));
      var header2 = FrameHeader(8, FrameType.PING, PingFrame.FLAG_ACK, 0);
      pingHandler.processPingFrame(PingFrame(header2, 2));

      await p1;
      await p2;
      verifyNoMoreInteractions(writer);
    });

    test('successful-ack-to-remote-ping', () async {
      var writer = FrameWriterMock();
      var pingHandler = PingHandler(writer);

      var header = FrameHeader(8, FrameType.PING, 0, 0);
      pingHandler.processPingFrame(PingFrame(header, 1));
      var header2 = FrameHeader(8, FrameType.PING, 0, 0);
      pingHandler.processPingFrame(PingFrame(header2, 2));

      verifyInOrder([
        writer.writePingFrame(1, ack: true),
        writer.writePingFrame(2, ack: true)
      ]);
      verifyNoMoreInteractions(writer);
    });

    test('ping-unknown-opaque-data', () async {
      var writer = FrameWriterMock();
      var pingHandler = PingHandler(writer);

      var future = pingHandler.ping();
      verify(writer.writePingFrame(1)).called(1);

      var header = FrameHeader(8, FrameType.PING, PingFrame.FLAG_ACK, 0);
      expect(() => pingHandler.processPingFrame(PingFrame(header, 2)),
          throwsA(isProtocolException));

      // Ensure outstanding pings will be completed with an error once we call
      // `pingHandler.terminate()`.
      unawaited(future.catchError(expectAsync2((error, _) {
        expect(error, 'hello world');
      })));
      pingHandler.terminate('hello world');
      verifyNoMoreInteractions(writer);
    });

    test('terminate-ping-handler', () async {
      var writer = FrameWriterMock();
      var pingHandler = PingHandler(writer);

      pingHandler.terminate('hello world');
      expect(() => pingHandler.processPingFrame(null),
          throwsA(isTerminatedException));
      expect(pingHandler.ping(), throwsA(isTerminatedException));
      verifyZeroInteractions(writer);
    });

    test('ping-non-zero-stream-id', () async {
      var writer = FrameWriterMock();
      var pingHandler = PingHandler(writer);

      var header = FrameHeader(8, FrameType.PING, PingFrame.FLAG_ACK, 1);
      expect(() => pingHandler.processPingFrame(PingFrame(header, 1)),
          throwsA(isProtocolException));
      verifyZeroInteractions(writer);
    });
  });
}

class FrameWriterMock extends Mock implements FrameWriter {}
