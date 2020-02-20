// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:http2/transport.dart';
import 'package:http2/src/async_utils/async_utils.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/flowcontrol/window.dart';
import 'package:http2/src/flowcontrol/window_handler.dart';
import 'package:http2/src/flowcontrol/connection_queues.dart';
import 'package:http2/src/flowcontrol/stream_queues.dart';
import 'package:http2/src/flowcontrol/queue_messages.dart';

void main() {
  group('flowcontrol', () {
    test('connection-message-queue-out', () {
      var fw = MockFrameWriter();
      var windowMock = MockOutgoingWindowHandler();
      var queue = ConnectionMessageQueueOut(windowMock, fw);

      fw.bufferIndicator.markUnBuffered();

      expect(queue.pendingMessages, 0);

      var headers = [Header.ascii('a', 'b')];
      var bytes = [1, 2, 3];

      // Send [HeadersMessage].
      queue.enqueueMessage(HeadersMessage(99, headers, false));
      expect(queue.pendingMessages, 0);
      verify(fw.writeHeadersFrame(99, headers, endStream: false)).called(1);
      verifyNoMoreInteractions(fw);
      verifyZeroInteractions(windowMock);

      clearInteractions(fw);

      // Send [DataMessage].
      windowMock.peerWindowSize = bytes.length;
      windowMock.positiveWindow.markUnBuffered();
      queue.enqueueMessage(DataMessage(99, bytes, false));
      expect(queue.pendingMessages, 0);
      verify(windowMock.decreaseWindow(bytes.length)).called(1);
      verify(fw.writeDataFrame(99, bytes, endStream: false)).called(1);
      verifyNoMoreInteractions(windowMock);
      verifyNoMoreInteractions(fw);

      clearInteractions(fw);
      clearInteractions(windowMock);

      // Send [DataMessage] if the connection window is too small.
      // Should trigger fragmentation and should write 1 byte.
      windowMock.peerWindowSize = 1;
      // decreaseWindow() marks the window as buffered in this case, so we need
      // our mock to do the same (otherwise, the call to markUnBuffered() below
      // has no effect).
      when(windowMock.decreaseWindow(1)).thenAnswer((_) {
        windowMock.positiveWindow.markBuffered();
      });
      queue.enqueueMessage(DataMessage(99, bytes, true));
      expect(queue.pendingMessages, 1);
      verify(windowMock.decreaseWindow(1)).called(1);
      verify(fw.writeDataFrame(99, bytes.sublist(0, 1), endStream: false))
          .called(1);
      verifyNoMoreInteractions(windowMock);
      verifyNoMoreInteractions(fw);

      clearInteractions(fw);
      reset(windowMock);

      // Now mark it as unbuffered. This should write the rest of the
      // [bytes.length - 1] bytes.
      windowMock.peerWindowSize = bytes.length - 1;
      windowMock.positiveWindow.markUnBuffered();
      verify(windowMock.decreaseWindow(bytes.length - 1)).called(1);
      verify(fw.writeDataFrame(99, bytes.sublist(1), endStream: true))
          .called(1);
      verifyNoMoreInteractions(windowMock);
      verifyNoMoreInteractions(fw);

      queue.startClosing();
      queue.done.then(expectAsync1((_) {
        expect(queue.pendingMessages, 0);
        expect(() => queue.enqueueMessage(DataMessage(99, bytes, true)),
            throwsA(const TypeMatcher<StateError>()));
      }));
    });

    test('connection-message-queue-in', () {
      const STREAM_ID = 99;
      final bytes = [1, 2, 3];

      var windowMock = MockIncomingWindowHandler();

      var queue = ConnectionMessageQueueIn(windowMock, (f) => f());
      expect(queue.pendingMessages, 0);

      var streamQueueMock = MockStreamMessageQueueIn();
      queue.insertNewStreamMessageQueue(STREAM_ID, streamQueueMock);

      // Insert a [DataFrame] and let it be buffered.
      var header = FrameHeader(0, 0, 0, STREAM_ID);
      queue.processDataFrame(DataFrame(header, 0, bytes));
      expect(queue.pendingMessages, 1);
      verify(windowMock.gotData(bytes.length)).called(1);
      verifyNoMoreInteractions(windowMock);
      verifyZeroInteractions(streamQueueMock);

      clearInteractions(windowMock);

      // Indicate that the stream queue has space, and make sure
      // the data is propagated from the connection to the stream
      // specific queue.
      streamQueueMock.bufferIndicator.markUnBuffered();
      verify(windowMock.dataProcessed(bytes.length)).called(1);
      var capturedMessage = verify(streamQueueMock.enqueueMessage(captureAny))
          .captured
          .single as DataMessage;
      expect(capturedMessage.streamId, STREAM_ID);
      expect(capturedMessage.bytes, bytes);

      verifyNoMoreInteractions(windowMock);
      verifyNoMoreInteractions(streamQueueMock);

      // TODO: Write tests for adding HeadersFrame/PushPromiseFrame.
    });

    test('connection-ignored-message-queue-in', () {
      const STREAM_ID = 99;
      final bytes = [1, 2, 3];

      var windowMock = MockIncomingWindowHandler();
      var queue = ConnectionMessageQueueIn(windowMock, (f) => f());

      // Insert a [DataFrame] and let it be buffered.
      var header = FrameHeader(0, 0, 0, STREAM_ID);
      queue.processIgnoredDataFrame(DataFrame(header, 0, bytes));
      expect(queue.pendingMessages, 0);
      verify(windowMock.gotData(bytes.length)).called(1);
      verifyNoMoreInteractions(windowMock);
    });
  });
}

class MockFrameWriter extends Mock implements FrameWriter {
  @override
  BufferIndicator bufferIndicator = BufferIndicator();
}

class MockStreamMessageQueueIn extends Mock implements StreamMessageQueueIn {
  @override
  BufferIndicator bufferIndicator = BufferIndicator();
}

class MockIncomingWindowHandler extends Mock implements IncomingWindowHandler {}

class MockOutgoingWindowHandler extends Mock
    implements OutgoingConnectionWindowHandler, OutgoingStreamWindowHandler {
  @override
  BufferIndicator positiveWindow = BufferIndicator();
  @override
  int peerWindowSize = Window().size;
}
