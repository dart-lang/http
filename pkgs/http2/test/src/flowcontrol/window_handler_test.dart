// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:http2/src/flowcontrol/window.dart';
import 'package:http2/src/flowcontrol/window_handler.dart';
import 'package:http2/src/frames/frames.dart';

import '../error_matchers.dart';

void main() {
  group('flowcontrol', () {
    void testAbstractOutgoingWindowHandler(
        AbstractOutgoingWindowHandler handler, Window window, int initialSize) {
      var sub = handler.positiveWindow.bufferEmptyEvents
          .listen(expectAsync1((_) {}, count: 0));

      expect(handler.peerWindowSize, initialSize);
      expect(window.size, initialSize);

      // If we're sending data to the remote end, we need to subtract
      // the number of bytes from the outgoing connection (and stream) windows.
      handler.decreaseWindow(100);
      expect(handler.peerWindowSize, initialSize - 100);
      expect(window.size, initialSize - 100);

      // If we received a window update frame, the window should be increased
      // again.
      var frameHeader = FrameHeader(4, FrameType.WINDOW_UPDATE, 0, 0);
      handler.processWindowUpdate(WindowUpdateFrame(frameHeader, 100));
      expect(handler.peerWindowSize, initialSize);
      expect(window.size, initialSize);

      sub.cancel();

      // If we decrease the outgoing window size to 0 or below, and
      // increase it again, we expect to get an update event.
      expect(handler.positiveWindow.wouldBuffer, isFalse);
      handler.decreaseWindow(window.size);
      expect(handler.positiveWindow.wouldBuffer, isTrue);
      sub = handler.positiveWindow.bufferEmptyEvents.listen(expectAsync1((_) {
        expect(handler.peerWindowSize, 1);
        expect(window.size, 1);
      }));

      // Now we trigger the 1 byte window increase
      handler.processWindowUpdate(WindowUpdateFrame(frameHeader, 1));
      sub.cancel();

      // If the remote end sends us [WindowUpdateFrame]s which increase it above
      // the maximum size, we throw a [FlowControlException].
      var frame = WindowUpdateFrame(frameHeader, Window.MAX_WINDOW_SIZE);
      expect(() => handler.processWindowUpdate(frame),
          throwsA(isFlowControlException));
    }

    test('outgoing-connection-window-handler', () {
      var window = Window();
      var initialSize = window.size;
      var handler = OutgoingConnectionWindowHandler(window);

      testAbstractOutgoingWindowHandler(handler, window, initialSize);
    });

    test('outgoing-stream-window-handler', () {
      var window = Window();
      var initialSize = window.size;
      var handler = OutgoingStreamWindowHandler(window);

      testAbstractOutgoingWindowHandler(handler, window, initialSize);

      // Test stream specific functionality: If the connection window
      // gets increased/decreased via a [SettingsFrame], all stream
      // windows need to get updated as well.

      window = Window();
      initialSize = window.size;
      handler = OutgoingStreamWindowHandler(window);

      expect(handler.positiveWindow.wouldBuffer, isFalse);
      final bufferEmpty = handler.positiveWindow.bufferEmptyEvents
          .listen(expectAsync1((_) {}, count: 0));
      handler.processInitialWindowSizeSettingChange(-window.size);
      expect(handler.positiveWindow.wouldBuffer, isTrue);
      expect(handler.peerWindowSize, 0);
      expect(window.size, 0);
      bufferEmpty.onData(expectAsync1((_) {}, count: 1));
      handler.processInitialWindowSizeSettingChange(1);
      expect(handler.positiveWindow.wouldBuffer, isFalse);
      expect(handler.peerWindowSize, 1);
      expect(window.size, 1);

      expect(
          () => handler.processInitialWindowSizeSettingChange(
              Window.MAX_WINDOW_SIZE + 1),
          throwsA(isFlowControlException));
    });

    test('incoming-window-handler', () {
      const STREAM_ID = 99;

      var fw = FrameWriterMock();
      var window = Window();
      var initialSize = window.size;
      var handler = IncomingWindowHandler.stream(fw, window, STREAM_ID);

      expect(handler.localWindowSize, initialSize);
      expect(window.size, initialSize);

      // If the remote end sends us now 100 bytes, it reduces the local
      // incoming window by 100 bytes. Once we handled these bytes, it,
      // will send a [WindowUpdateFrame] to the remote peer to ACK it.
      handler.gotData(100);
      expect(handler.localWindowSize, initialSize - 100);
      expect(window.size, initialSize - 100);

      // The data might sit in a queue. Once the user drains enough data of
      // the queue, we will start ACKing the data and the window becomes
      // positive again.
      handler.dataProcessed(100);
      expect(handler.localWindowSize, initialSize);
      expect(window.size, initialSize);
      verify(fw.writeWindowUpdate(100, streamId: STREAM_ID)).called(1);
      verifyNoMoreInteractions(fw);
    });
  });
}

class FrameWriterMock extends Mock implements FrameWriter {}
