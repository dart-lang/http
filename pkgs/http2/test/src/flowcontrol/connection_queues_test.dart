// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http2/src/async_utils/async_utils.dart';
import 'package:http2/src/flowcontrol/connection_queues.dart';
import 'package:http2/src/flowcontrol/queue_messages.dart';
import 'package:http2/src/flowcontrol/window.dart';
import 'package:http2/src/flowcontrol/window_handler.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/transport.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'mocks.mocks.dart';

void main() {
  group('flowcontrol', () {
    test('connection-message-queue-out', () {
      var fw = MockFrameWriter();
      when(fw.bufferIndicator).thenReturn(BufferIndicator());
      when(
        fw.writeHeadersFrame(any, any, endStream: anyNamed('endStream')),
      ).thenReturn(null);
      when(
        fw.writeDataFrame(any, any, endStream: anyNamed('endStream')),
      ).thenReturn(null);
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
      verify(fw.bufferIndicator).called(greaterThan(0));
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
      verify(fw.bufferIndicator).called(greaterThan(0));
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
      verify(fw.bufferIndicator).called(greaterThan(0));
      verify(
        fw.writeDataFrame(99, bytes.sublist(0, 1), endStream: false),
      ).called(1);
      verifyNoMoreInteractions(windowMock);
      verifyNoMoreInteractions(fw);

      clearInteractions(fw);
      reset(windowMock);

      // Now mark it as unbuffered. This should write the rest of the
      // [bytes.length - 1] bytes.
      windowMock.peerWindowSize = bytes.length - 1;
      windowMock.positiveWindow.markUnBuffered();
      verify(windowMock.decreaseWindow(bytes.length - 1)).called(1);
      verify(
        fw.writeDataFrame(99, bytes.sublist(1), endStream: true),
      ).called(1);
      verifyNoMoreInteractions(windowMock);
      verify(fw.bufferIndicator).called(greaterThan(0));
      verifyNoMoreInteractions(fw);

      queue.startClosing();
      queue.done.then(
        expectAsync1((_) {
          expect(queue.pendingMessages, 0);
          expect(
            () => queue.enqueueMessage(DataMessage(99, bytes, true)),
            throwsA(const TypeMatcher<StateError>()),
          );
        }),
      );
    });

    group('connection-message-queue-out drains', () {
      late MockFrameWriter fw;
      late MockOutgoingWindowHandler windowMock;
      late ConnectionMessageQueueOut queue;

      setUp(() {
        fw = MockFrameWriter();
        when(fw.bufferIndicator).thenReturn(BufferIndicator());
        windowMock =
            MockOutgoingWindowHandler()
              ..peerWindowSize = 1 << 20
              ..positiveWindow.markUnBuffered();
        queue = ConnectionMessageQueueOut(windowMock, fw);
      });

      test('every queued message once the frame writer stops buffering', () {
        var headers = [Header.ascii('a', 'b')];
        for (var id = 1; id < 20; id += 2) {
          queue.enqueueMessage(HeadersMessage(id, headers, false));
        }
        expect(queue.pendingMessages, 10);

        fw.bufferIndicator.markUnBuffered();

        // Without waiting for the event loop.
        expect(queue.pendingMessages, 0);
        verify(fw.writeHeadersFrame(any, headers, endStream: false)).called(10);
      });

      test('until the frame writer buffers again', () {
        var written = 0;
        when(
          fw.writeHeadersFrame(any, any, endStream: anyNamed('endStream')),
        ).thenAnswer((_) {
          if (++written == 3) fw.bufferIndicator.markBuffered();
        });
        var headers = [Header.ascii('a', 'b')];
        for (var id = 1; id < 20; id += 2) {
          queue.enqueueMessage(HeadersMessage(id, headers, false));
        }

        fw.bufferIndicator.markUnBuffered();

        expect(written, 3);
        expect(queue.pendingMessages, 7);
      });

      test('a large upload over several turns of the event loop', () async {
        fw.bufferIndicator.markUnBuffered();
        var chunk = List.filled(40 * 1024, 0);

        queue
          ..enqueueMessage(HeadersMessage(1, [Header.ascii('a', 'b')], false))
          ..enqueueMessage(DataMessage(1, chunk, false));
        // Queued behind a message which cannot be sent yet.
        fw.bufferIndicator.markBuffered();
        queue
          ..enqueueMessage(DataMessage(1, chunk, false))
          ..enqueueMessage(DataMessage(1, chunk, false))
          ..enqueueMessage(DataMessage(1, chunk, true));
        clearInteractions(fw);

        fw.bufferIndicator.markUnBuffered();
        expect(queue.pendingMessages, 1);

        await Future<void>.delayed(Duration.zero);
        expect(queue.pendingMessages, 0);
        verify(
          fw.writeDataFrame(1, chunk, endStream: anyNamed('endStream')),
        ).called(3);
      });
    });

    test('connection-message-queue-in', () {
      const STREAM_ID = 99;
      final bytes = [1, 2, 3];

      var windowMock = MockIncomingWindowHandler();
      when(windowMock.gotData(any)).thenReturn(null);
      when(windowMock.dataProcessed(any)).thenReturn(null);

      var queue = ConnectionMessageQueueIn(windowMock, (f) => f());
      expect(queue.pendingMessages, 0);

      var streamQueueMock = MockStreamMessageQueueIn();
      when(streamQueueMock.bufferIndicator).thenReturn(BufferIndicator());
      when(streamQueueMock.enqueueMessage(any)).thenReturn(null);

      queue.insertNewStreamMessageQueue(STREAM_ID, streamQueueMock);

      // Insert a [DataFrame] and let it be buffered.
      var header = FrameHeader(0, 0, 0, STREAM_ID);
      queue.processDataFrame(DataFrame(header, 0, bytes));
      expect(queue.pendingMessages, 1);
      verify(windowMock.gotData(bytes.length)).called(1);
      verifyNoMoreInteractions(windowMock);
      verify(streamQueueMock.bufferIndicator).called(greaterThan(0));
      verifyNoMoreInteractions(streamQueueMock);

      clearInteractions(windowMock);

      // Indicate that the stream queue has space, and make sure
      // the data is propagated from the connection to the stream
      // specific queue.
      streamQueueMock.bufferIndicator.markUnBuffered();
      verify(windowMock.dataProcessed(bytes.length)).called(1);
      var capturedMessage =
          verify(streamQueueMock.enqueueMessage(captureAny)).captured.single
              as DataMessage;
      expect(capturedMessage.streamId, STREAM_ID);
      expect(capturedMessage.bytes, bytes);

      verifyNoMoreInteractions(windowMock);
      verify(streamQueueMock.bufferIndicator).called(greaterThan(0));
      verifyNoMoreInteractions(streamQueueMock);

      // TODO: Write tests for adding HeadersFrame/PushPromiseFrame.
    });

    test('connection-ignored-message-queue-in', () {
      const STREAM_ID = 99;
      final bytes = [1, 2, 3];

      var windowMock = MockIncomingWindowHandler();
      when(windowMock.gotData(any)).thenReturn(null);
      var queue = ConnectionMessageQueueIn(windowMock, (f) => f());

      // Insert a [DataFrame] and let it be buffered.
      var header = FrameHeader(0, 0, 0, STREAM_ID);
      queue.processIgnoredDataFrame(DataFrame(header, 0, bytes));
      expect(queue.pendingMessages, 0);
      verify(windowMock.dataProcessed(bytes.length)).called(1);
      verifyNoMoreInteractions(windowMock);
    });
  });
}

class MockOutgoingWindowHandler extends Mock
    implements OutgoingConnectionWindowHandler, OutgoingStreamWindowHandler {
  @override
  BufferIndicator positiveWindow = BufferIndicator();
  @override
  int peerWindowSize = Window().size;
}
