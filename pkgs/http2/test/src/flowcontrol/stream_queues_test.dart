// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http2/src/async_utils/async_utils.dart';
import 'package:http2/src/flowcontrol/queue_messages.dart';
import 'package:http2/src/flowcontrol/stream_queues.dart';
import 'package:http2/src/flowcontrol/window.dart';
import 'package:http2/src/flowcontrol/window_handler.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/transport.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'mocks.mocks.dart';

void main() {
  group('flowcontrol', () {
    const STREAM_ID = 99;
    const BYTES = [1, 2, 3];

    group('stream-message-queue-out', () {
      for (final initialWindow in [0, 1]) {
        test('end-stream waits for updates from $initialWindow', () async {
          final sent = <DataMessage>[];
          final connectionQueue = MockConnectionMessageQueueOut();
          when(connectionQueue.enqueueMessage(any)).thenAnswer((invocation) {
            sent.add(invocation.positionalArguments.single as DataMessage);
          });
          final window = OutgoingStreamWindowHandler(
            Window(initialSize: initialWindow),
          );
          final queue = StreamMessageQueueOut(
            STREAM_ID,
            window,
            connectionQueue,
          );
          queue.bufferIndicator.bufferEmptyEvents.listen(
            expectAsync1((_) {
              // A synchronous drain callback must not reopen the closing queue.
              expect(queue.isClosing, isTrue);
              expect(
                () =>
                    queue.enqueueMessage(DataMessage(STREAM_ID, BYTES, false)),
                throwsStateError,
              );
            }),
          );

          queue.enqueueMessage(DataMessage(STREAM_ID, BYTES, true));
          expect(queue.isClosing, isTrue);
          expect(queue.wasClosed, isFalse);
          expect(queue.pendingMessages, 1);
          expect(queue.writtenBytes, initialWindow);
          expect(queue.bufferIndicator.wouldBuffer, isTrue);
          expect(
            () => queue.enqueueMessage(DataMessage(STREAM_ID, BYTES, false)),
            throwsStateError,
          );

          for (var written = initialWindow; written < BYTES.length; written++) {
            expect(queue.wasClosed, isFalse);
            window.processWindowUpdate(
              WindowUpdateFrame(
                FrameHeader(4, FrameType.WINDOW_UPDATE, 0, STREAM_ID),
                1,
              ),
            );
          }
          await queue.done;
          expect(queue.wasClosed, isTrue);
          expect(queue.pendingMessages, 0);
          expect(queue.bufferIndicator.wouldBuffer, isFalse);
          expect(queue.writtenBytes, BYTES.length);
          expect(sent.expand((message) => message.bytes), BYTES);
          expect(sent.take(sent.length - 1).every((m) => !m.endStream), isTrue);
          expect(sent.last.endStream, isTrue);
        });
      }

      test('end-stream headers close after reaching the connection queue', () {
        final connectionQueue = MockConnectionMessageQueueOut();
        final window = OutgoingStreamWindowHandler(Window(initialSize: 0));
        final queue = StreamMessageQueueOut(STREAM_ID, window, connectionQueue);
        when(connectionQueue.enqueueMessage(any)).thenAnswer((_) {
          expect(queue.wasClosed, isFalse);
        });

        queue.enqueueMessage(HeadersMessage(STREAM_ID, [], true));
        expect(queue.wasClosed, isTrue);
        expect(queue.pendingMessages, 0);
      });

      test('reset remains allowed after end-stream', () {
        final connectionQueue = MockConnectionMessageQueueOut();
        when(connectionQueue.enqueueMessage(any)).thenReturn(null);
        final window = OutgoingStreamWindowHandler(Window(initialSize: 0));
        final queue = StreamMessageQueueOut(STREAM_ID, window, connectionQueue);
        queue.enqueueMessage(HeadersMessage(STREAM_ID, [], true));
        expect(queue.wasClosed, isTrue);
        final reset = ResetStreamMessage(STREAM_ID, ErrorCode.CANCEL);
        queue.enqueueMessage(reset);
        verify(connectionQueue.enqueueMessage(reset)).called(1);
        expect(queue.pendingMessages, 0);
      });

      test('empty end-stream data closes with an empty window', () async {
        final connectionQueue = MockConnectionMessageQueueOut();
        when(connectionQueue.enqueueMessage(any)).thenReturn(null);
        final window = OutgoingStreamWindowHandler(Window(initialSize: 0));
        final queue = StreamMessageQueueOut(STREAM_ID, window, connectionQueue);

        final subscription = queue.bufferIndicator.bufferEmptyEvents.listen(
          expectAsync1((_) {
            expect(queue.isClosing, isTrue);
            expect(
              () => queue.enqueueMessage(DataMessage(STREAM_ID, BYTES, false)),
              throwsStateError,
            );
          }),
        );
        addTearDown(subscription.cancel);

        queue.enqueueMessage(DataMessage(STREAM_ID, [], true));
        await queue.done;
        expect(queue.wasClosed, isTrue);
        expect(queue.pendingMessages, 0);
        final message =
            verify(connectionQueue.enqueueMessage(captureAny)).captured.single
                as DataMessage;
        expect(message.bytes, isEmpty);
        expect(message.endStream, isTrue);
      });

      for (final error in [null, StateError('transport failed')]) {
        test('termination discards pending end-stream data: $error', () async {
          final connectionQueue = MockConnectionMessageQueueOut();
          final window = OutgoingStreamWindowHandler(Window(initialSize: 0));
          final queue = StreamMessageQueueOut(
            STREAM_ID,
            window,
            connectionQueue,
          );

          queue.enqueueMessage(DataMessage(STREAM_ID, BYTES, true));
          expect(queue.wasClosed, isFalse);
          queue.terminate(error);
          await queue.done;
          expect(queue.wasTerminated, isTrue);
          expect(queue.wasClosed, isTrue);
          expect(queue.pendingMessages, 0);
          window.processWindowUpdate(
            WindowUpdateFrame(
              FrameHeader(4, FrameType.WINDOW_UPDATE, 0, STREAM_ID),
              BYTES.length,
            ),
          );
          verifyZeroInteractions(connectionQueue);
        });
      }

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
