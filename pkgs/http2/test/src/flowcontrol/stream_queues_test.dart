// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:http2/transport.dart';
import 'package:http2/src/async_utils/async_utils.dart';
import 'package:http2/src/flowcontrol/queue_messages.dart';
import 'package:http2/src/flowcontrol/stream_queues.dart';
import 'package:http2/src/flowcontrol/window_handler.dart';
import 'package:http2/src/flowcontrol/connection_queues.dart';

import '../mock_utils.dart';

main() {
  group('flowcontrol', () {
    const STREAM_ID = 99;
    const BYTES = const [1, 2, 3];

    group('stream-message-queue-out', () {
      test('window-big-enough', () {
        var connectionQueueMock = new MockConnectionMessageQueueOut();
        var windowMock = new MockOutgoingStreamWindowHandler();

        windowMock.positiveWindow.markUnBuffered();
        var queue = new StreamMessageQueueOut(
            STREAM_ID, windowMock, connectionQueueMock);

        expect(queue.bufferIndicator.wouldBuffer, isFalse);
        expect(queue.pendingMessages, 0);

        windowMock.peerWindowSize = BYTES.length;
        windowMock.mock_decreaseWindow = expectAsync1((int difference) {
          expect(difference, BYTES.length);
        });
        connectionQueueMock.mock_enqueueMessage =
            expectAsync1((Message message) {
          expect(message is DataMessage, isTrue);
          DataMessage dataMessage = message;
          expect(dataMessage.bytes, BYTES);
          expect(dataMessage.endStream, isTrue);
        });
        queue.enqueueMessage(new DataMessage(STREAM_ID, BYTES, true));
      });

      test('window-smaller-than-necessary', () {
        var connectionQueueMock = new MockConnectionMessageQueueOut();
        var windowMock = new MockOutgoingStreamWindowHandler();

        windowMock.positiveWindow.markUnBuffered();
        var queue = new StreamMessageQueueOut(
            STREAM_ID, windowMock, connectionQueueMock);

        expect(queue.bufferIndicator.wouldBuffer, isFalse);
        expect(queue.pendingMessages, 0);

        // We set the window size fixed to 1, which means all the data messages
        // will get fragmented to 1 byte.
        windowMock.peerWindowSize = 1;
        windowMock.mock_decreaseWindow = expectAsync1((int difference) {
          expect(difference, 1);
        }, count: BYTES.length);
        int counter = 0;
        connectionQueueMock.mock_enqueueMessage =
            expectAsync1((Message message) {
          expect(message is DataMessage, isTrue);
          DataMessage dataMessage = message;
          expect(dataMessage.bytes, BYTES.sublist(counter, counter + 1));
          counter++;
          expect(dataMessage.endStream, counter == BYTES.length);
        }, count: BYTES.length);
        queue.enqueueMessage(new DataMessage(STREAM_ID, BYTES, true));

        expect(queue.pendingMessages, 0);
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
        windowMock.mock_decreaseWindow = expectAsync1((_) {}, count: 0);
        connectionQueueMock.mock_enqueueMessage =
            expectAsync1((_) {}, count: 0);
        queue.enqueueMessage(new DataMessage(STREAM_ID, BYTES, true));
        expect(queue.bufferIndicator.wouldBuffer, isTrue);
        expect(queue.pendingMessages, 1);
      });
    });

    group('stream-message-queue-in', () {
      test('data-end-of-stream', () {
        var windowMock = new MockIncomingWindowHandler();
        var queue = new StreamMessageQueueIn(windowMock);

        expect(queue.pendingMessages, 0);
        queue.messages.listen(expectAsync1((StreamMessage message) {
          expect(message is DataStreamMessage, isTrue);

          DataStreamMessage dataMessage = message;
          expect(dataMessage.bytes, BYTES);
        }), onDone: expectAsync0(() {}));
        windowMock.mock_gotData = expectAsync1((int difference) {
          expect(difference, BYTES.length);
        });
        windowMock.mock_dataProcessed = expectAsync1((int difference) {
          expect(difference, BYTES.length);
        });
        queue.enqueueMessage(new DataMessage(STREAM_ID, BYTES, true));
        expect(queue.bufferIndicator.wouldBuffer, isFalse);
      });
    });

    test('data-end-of-stream--paused', () {
      const STREAM_ID = 99;
      final bytes = [1, 2, 3];

      var windowMock = new MockIncomingWindowHandler();
      var queue = new StreamMessageQueueIn(windowMock);

      var sub = queue.messages.listen(
          expectAsync1((_) {}, count: 0), onDone: expectAsync0(() {}, count: 0));
      sub.pause();

      // We assert that we got the data, but it wasn't processed.
      windowMock.mock_gotData = expectAsync1((int difference) {
        expect(difference, bytes.length);
      });
      windowMock.mock_dataProcessed = expectAsync1((_) {}, count: 0);

      expect(queue.pendingMessages, 0);
      queue.enqueueMessage(new DataMessage(STREAM_ID, bytes, true));
      expect(queue.pendingMessages, 1);
      expect(queue.bufferIndicator.wouldBuffer, isTrue);
    });

    // TODO: Add tests for Headers/HeadersPush messages.
  });
}


class MockConnectionMessageQueueOut extends SmartMock
                                    implements ConnectionMessageQueueOut { }


class MockIncomingWindowHandler extends SmartMock
                                implements IncomingWindowHandler { }

class MockOutgoingStreamWindowHandler extends SmartMock
                                      implements OutgoingStreamWindowHandler {
  final BufferIndicator positiveWindow = new BufferIndicator();
  int peerWindowSize;
}
