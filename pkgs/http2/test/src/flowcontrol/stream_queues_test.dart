// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:http2/transport.dart';
import 'package:http2/src/async_utils/async_utils.dart';
import 'package:http2/src/flowcontrol/queue_messages.dart';
import 'package:http2/src/flowcontrol/stream_queues.dart';
import 'package:http2/src/flowcontrol/window_handler.dart';
import 'package:http2/src/flowcontrol/connection_queues.dart';

main() {
  group('flowcontrol', () {
    const STREAM_ID = 99;
    const BYTES = const [1, 2, 3];

    group('stream-message-queue-out', () {
      test('window-big-enough', () {
        dynamic connectionQueueMock = new MockConnectionMessageQueueOut();
        dynamic windowMock = new MockOutgoingStreamWindowHandler();

        windowMock.positiveWindow.markUnBuffered();
        var queue = new StreamMessageQueueOut(
            STREAM_ID, windowMock, connectionQueueMock);

        expect(queue.bufferIndicator.wouldBuffer, isFalse);
        expect(queue.pendingMessages, 0);

        windowMock.peerWindowSize = BYTES.length;
        queue.enqueueMessage(new DataMessage(STREAM_ID, BYTES, true));
        verify(windowMock.decreaseWindow(BYTES.length)).called(1);
        final capturedMessage =
            verify(connectionQueueMock.enqueueMessage(captureAny))
                .captured
                .single;
        expect(capturedMessage, const TypeMatcher<DataMessage>());
        DataMessage capturedDataMessage = capturedMessage;
        expect(capturedDataMessage.bytes, BYTES);
        expect(capturedDataMessage.endStream, isTrue);
      });

      test('window-smaller-than-necessary', () {
        dynamic connectionQueueMock = new MockConnectionMessageQueueOut();
        dynamic windowMock = new MockOutgoingStreamWindowHandler();

        windowMock.positiveWindow.markUnBuffered();
        var queue = new StreamMessageQueueOut(
            STREAM_ID, windowMock, connectionQueueMock);

        expect(queue.bufferIndicator.wouldBuffer, isFalse);
        expect(queue.pendingMessages, 0);

        // We set the window size fixed to 1, which means all the data messages
        // will get fragmented to 1 byte.
        windowMock.peerWindowSize = 1;
        queue.enqueueMessage(new DataMessage(STREAM_ID, BYTES, true));

        expect(queue.pendingMessages, 0);
        verify(windowMock.decreaseWindow(1)).called(BYTES.length);
        final messages =
            verify(connectionQueueMock.enqueueMessage(captureAny)).captured;
        expect(messages.length, BYTES.length);
        for (var counter = 0; counter < messages.length; counter++) {
          expect(messages[counter], const TypeMatcher<DataMessage>());
          DataMessage dataMessage = messages[counter];
          expect(dataMessage.bytes, BYTES.sublist(counter, counter + 1));
          expect(dataMessage.endStream, counter == BYTES.length - 1);
        }
        verifyNoMoreInteractions(windowMock);
      });

      test('window-empty', () {
        var connectionQueueMock = new MockConnectionMessageQueueOut();
        var windowMock = new MockOutgoingStreamWindowHandler();

        windowMock.positiveWindow.markUnBuffered();
        var queue = new StreamMessageQueueOut(
            STREAM_ID, windowMock, connectionQueueMock);

        expect(queue.bufferIndicator.wouldBuffer, isFalse);
        expect(queue.pendingMessages, 0);

        windowMock.peerWindowSize = 0;
        queue.enqueueMessage(new DataMessage(STREAM_ID, BYTES, true));
        expect(queue.bufferIndicator.wouldBuffer, isTrue);
        expect(queue.pendingMessages, 1);
        verifyZeroInteractions(windowMock);
        verifyZeroInteractions(connectionQueueMock);
      });
    });

    group('stream-message-queue-in', () {
      test('data-end-of-stream', () {
        dynamic windowMock = new MockIncomingWindowHandler();
        dynamic queue = new StreamMessageQueueIn(windowMock);

        expect(queue.pendingMessages, 0);
        queue.messages.listen(expectAsync1((StreamMessage message) {
          expect(message is DataStreamMessage, isTrue);

          DataStreamMessage dataMessage = message;
          expect(dataMessage.bytes, BYTES);
        }), onDone: expectAsync0(() {}));
        queue.enqueueMessage(new DataMessage(STREAM_ID, BYTES, true));
        expect(queue.bufferIndicator.wouldBuffer, isFalse);
        verifyInOrder([
          windowMock.gotData(BYTES.length),
          windowMock.dataProcessed(BYTES.length)
        ]);
        verifyNoMoreInteractions(windowMock);
      });
    });

    test('data-end-of-stream--paused', () {
      const STREAM_ID = 99;
      final bytes = [1, 2, 3];

      dynamic windowMock = new MockIncomingWindowHandler();
      dynamic queue = new StreamMessageQueueIn(windowMock);

      var sub = queue.messages.listen(expectAsync1((_) {}, count: 0),
          onDone: expectAsync0(() {}, count: 0));
      sub.pause();

      expect(queue.pendingMessages, 0);
      queue.enqueueMessage(new DataMessage(STREAM_ID, bytes, true));
      expect(queue.pendingMessages, 1);
      expect(queue.bufferIndicator.wouldBuffer, isTrue);
      // We assert that we got the data, but it wasn't processed.
      verify(windowMock.gotData(bytes.length)).called(1);
      verifyNever(windowMock.dataProcessed(any));
    });

    // TODO: Add tests for Headers/HeadersPush messages.
  });
}

class MockConnectionMessageQueueOut extends Mock
    implements ConnectionMessageQueueOut {}

class MockIncomingWindowHandler extends Mock implements IncomingWindowHandler {}

class MockOutgoingStreamWindowHandler extends Mock
    implements OutgoingStreamWindowHandler {
  final BufferIndicator positiveWindow = new BufferIndicator();
  int peerWindowSize;
}
