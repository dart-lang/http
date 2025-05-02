// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http2/src/async_utils/async_utils.dart';
import 'package:http2/src/flowcontrol/queue_messages.dart';
import 'package:http2/src/flowcontrol/stream_queues.dart';
import 'package:http2/transport.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'mocks.mocks.dart';

void main() {
  group('flowcontrol', () {
    const STREAM_ID = 99;
    const BYTES = [1, 2, 3];

    group('stream-message-queue-out', () {
      test('window-big-enough', () {
        var connectionQueueMock = MockConnectionMessageQueueOut();
        when(connectionQueueMock.enqueueMessage(any)).thenReturn(null);
        var windowMock = MockOutgoingStreamWindowHandler();
        when(windowMock.positiveWindow).thenReturn(BufferIndicator());
        when(windowMock.decreaseWindow(any)).thenReturn(null);

        windowMock.positiveWindow.markUnBuffered();
        var queue = StreamMessageQueueOut(
          STREAM_ID,
          windowMock,
          connectionQueueMock,
        );

        expect(queue.bufferIndicator.wouldBuffer, isFalse);
        expect(queue.pendingMessages, 0);
        when(windowMock.peerWindowSize).thenReturn(BYTES.length);

        queue.enqueueMessage(DataMessage(STREAM_ID, BYTES, true));
        verify(windowMock.decreaseWindow(BYTES.length)).called(1);
        final capturedMessage =
            verify(
              connectionQueueMock.enqueueMessage(captureAny),
            ).captured.single;
        expect(capturedMessage, const TypeMatcher<DataMessage>());
        var capturedDataMessage = capturedMessage as DataMessage;
        expect(capturedDataMessage.bytes, BYTES);
        expect(capturedDataMessage.endStream, isTrue);
      });

      test('window-smaller-than-necessary', () {
        var connectionQueueMock = MockConnectionMessageQueueOut();
        when(connectionQueueMock.enqueueMessage(any)).thenReturn(null);
        var windowMock = MockOutgoingStreamWindowHandler();
        when(windowMock.positiveWindow).thenReturn(BufferIndicator());
        when(windowMock.decreaseWindow(any)).thenReturn(null);
        windowMock.positiveWindow.markUnBuffered();
        var queue = StreamMessageQueueOut(
          STREAM_ID,
          windowMock,
          connectionQueueMock,
        );

        expect(queue.bufferIndicator.wouldBuffer, isFalse);
        expect(queue.pendingMessages, 0);

        // We set the window size fixed to 1, which means all the data messages
        // will get fragmented to 1 byte.
        when(windowMock.peerWindowSize).thenReturn(1);
        queue.enqueueMessage(DataMessage(STREAM_ID, BYTES, true));

        expect(queue.pendingMessages, 0);
        verify(windowMock.decreaseWindow(1)).called(BYTES.length);
        final messages =
            verify(connectionQueueMock.enqueueMessage(captureAny)).captured;
        expect(messages, hasLength(BYTES.length));
        for (var counter = 0; counter < messages.length; counter++) {
          expect(messages[counter], const TypeMatcher<DataMessage>());
          var dataMessage = messages[counter] as DataMessage;
          expect(dataMessage.bytes, BYTES.sublist(counter, counter + 1));
          expect(dataMessage.endStream, counter == BYTES.length - 1);
        }
        verify(windowMock.positiveWindow).called(greaterThan(0));
        verify(windowMock.peerWindowSize).called(greaterThan(0));
        verifyNoMoreInteractions(windowMock);
      });

      test('window-empty', () {
        var connectionQueueMock = MockConnectionMessageQueueOut();
        var windowMock = MockOutgoingStreamWindowHandler();
        when(windowMock.positiveWindow).thenReturn(BufferIndicator());
        windowMock.positiveWindow.markUnBuffered();
        var queue = StreamMessageQueueOut(
          STREAM_ID,
          windowMock,
          connectionQueueMock,
        );

        expect(queue.bufferIndicator.wouldBuffer, isFalse);
        expect(queue.pendingMessages, 0);

        when(windowMock.peerWindowSize).thenReturn(0);
        queue.enqueueMessage(DataMessage(STREAM_ID, BYTES, true));
        expect(queue.bufferIndicator.wouldBuffer, isTrue);
        expect(queue.pendingMessages, 1);
        verify(windowMock.positiveWindow).called(greaterThan(0));
        verify(windowMock.peerWindowSize).called(greaterThan(0));
        verifyNoMoreInteractions(windowMock);
        verifyZeroInteractions(connectionQueueMock);
      });
    });

    group('stream-message-queue-in', () {
      test('data-end-of-stream', () {
        var windowMock = MockIncomingWindowHandler();
        when(windowMock.gotData(any)).thenReturn(null);
        when(windowMock.dataProcessed(any)).thenReturn(null);
        var queue = StreamMessageQueueIn(windowMock);

        expect(queue.pendingMessages, 0);
        queue.messages.listen(
          expectAsync1((StreamMessage message) {
            expect(message, isA<DataStreamMessage>());

            var dataMessage = message as DataStreamMessage;
            expect(dataMessage.bytes, BYTES);
          }),
          onDone: expectAsync0(() {}),
        );
        queue.enqueueMessage(DataMessage(STREAM_ID, BYTES, true));
        expect(queue.bufferIndicator.wouldBuffer, isFalse);
        verifyInOrder([
          windowMock.gotData(BYTES.length),
          windowMock.dataProcessed(BYTES.length),
        ]);
        verifyNoMoreInteractions(windowMock);
      });
    });

    test('data-end-of-stream--paused', () {
      const STREAM_ID = 99;
      final bytes = [1, 2, 3];

      var windowMock = MockIncomingWindowHandler();
      when(windowMock.gotData(any)).thenReturn(null);
      var queue = StreamMessageQueueIn(windowMock);

      var sub = queue.messages.listen(
        expectAsync1((_) {}, count: 0),
        onDone: expectAsync0(() {}, count: 0),
      );
      sub.pause();

      expect(queue.pendingMessages, 0);
      queue.enqueueMessage(DataMessage(STREAM_ID, bytes, true));
      expect(queue.pendingMessages, 1);
      expect(queue.bufferIndicator.wouldBuffer, isTrue);
      // We assert that we got the data, but it wasn't processed.
      verify(windowMock.gotData(bytes.length)).called(1);
      // verifyNever(windowMock.dataProcessed(any));
    });

    // TODO: Add tests for Headers/HeadersPush messages.
  });
}
