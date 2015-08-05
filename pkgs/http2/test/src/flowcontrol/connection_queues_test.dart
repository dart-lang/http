// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/unittest.dart';

import 'package:http2/transport.dart';
import 'package:http2/src/async_utils/async_utils.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/flowcontrol/window.dart';
import 'package:http2/src/flowcontrol/window_handler.dart';
import 'package:http2/src/flowcontrol/connection_queues.dart';
import 'package:http2/src/flowcontrol/stream_queues.dart';
import 'package:http2/src/flowcontrol/queue_messages.dart';

import '../error_matchers.dart';
import '../mock_utils.dart';

main() {
  group('flowcontrol', () {
    test('connection-message-queue-out', () {
      var fw = new MockFrameWriter();
      var windowMock = new MockOutgoingWindowHandler();
      var queue = new ConnectionMessageQueueOut(windowMock, fw);

      fw.bufferIndicator.markUnBuffered();

      expect(queue.pendingMessages, 0);

      var headers = [new Header.ascii('a', 'b')];
      var bytes = [1, 2, 3];

      // Send [HeadersMessage].
      var c = new TestCounter();
      fw.mock_writeHeadersFrame = (int streamId,
                                   List<Header> sendingHeaders,
                                   {bool endStream}) {
        expect(streamId, 99);
        expect(sendingHeaders, headers);
        expect(endStream, false);
        c.got();
      };
      queue.enqueueMessage(new HeadersMessage(99, headers, false));
      expect(queue.pendingMessages, 0);

      fw.mock_writeHeadersFrame = null;

      // Send [DataMessage].
      c = new TestCounter(count: 2);
      windowMock.peerWindowSize = bytes.length;
      windowMock.mock_decreaseWindow = (int difference) {
        expect(difference, bytes.length);
        c.got();
      };
      fw.mock_writeDataFrame = (int streamId,
                                List<Header> sendingBytes,
                                {bool endStream}) {
        expect(streamId, 99);
        expect(sendingBytes, bytes);
        expect(endStream, true);
        c.got();
      };
      queue.enqueueMessage(new DataMessage(99, bytes, true));
      expect(queue.pendingMessages, 0);

      fw.mock_writeDataFrame = null;

      // Send [DataMessage] if the connection window is too small.
      // Should trigger fragmentation and should write 1 byte.
      c = new TestCounter(count: 2);
      windowMock.peerWindowSize = 1;
      windowMock.mock_decreaseWindow = (int difference) {
        expect(difference, 1);
        c.got();
      };
      fw.mock_writeDataFrame = (int streamId, List<Header> sendingBytes,
                                {bool endStream}) {
        expect(streamId, 99);
        expect(sendingBytes, bytes.sublist(0, 1));
        expect(endStream, false);
        c.got();
      };
      queue.enqueueMessage(new DataMessage(99, bytes, true));
      expect(queue.pendingMessages, 1);

      // Now mark it as unbuffered. This should write the rest of the
      // [bytes.length - 1] bytes.
      c = new TestCounter(count: 2);
      windowMock.mock_decreaseWindow = (int difference) {
        expect(difference, bytes.length - 1);
        c.got();
      };
      fw.mock_writeDataFrame = (int streamId, List<Header> sendingBytes,
                                {bool endStream}) {
        expect(streamId, 99);
        expect(sendingBytes, bytes.sublist(1));
        expect(endStream, true);
        c.got();
      };
      windowMock.peerWindowSize = bytes.length - 1;
      windowMock.positiveWindow.markUnBuffered();

      // Terminate it now, ensure messages get cleared and we no longer
      // enqueue messages.
      queue.terminate();
      expect(queue.pendingMessages, 0);
      fw = new MockFrameWriter();
      windowMock = new MockOutgoingWindowHandler();
      queue.enqueueMessage(new DataMessage(99, bytes, true));
      expect(queue.pendingMessages, 0);
    });

    test('connection-message-queue-in', () {
      const STREAM_ID = 99;
      final bytes = [1, 2, 3];

      var windowMock = new MockIncomingWindowHandler();

      var queue = new ConnectionMessageQueueIn(windowMock);
      expect(queue.pendingMessages, 0);

      var streamQueueMock = new MockStreamMessageQueueIn();
      queue.insertNewStreamMessageQueue(STREAM_ID, streamQueueMock);

      // Insert a [DataFrame] and let it be buffered.
      var header = new FrameHeader(0, 0, 0, STREAM_ID);
      var c = new TestCounter();
      windowMock.mock_gotData = (int diff) {
        expect(diff, bytes.length);
        c.got();
      };
      queue.processDataFrame(new DataFrame(header, 0, bytes));
      expect(queue.pendingMessages, 1);

      // Indicate that the stream queue has space, and make sure
      // the data is propagated from the connection to the stream
      // specific queue.
      c = new TestCounter(count: 2);
      windowMock.mock_gotData = null;
      windowMock.mock_dataProcessed = (int diff) {
        expect(diff, bytes.length);
        c.got();
      };
      streamQueueMock.mock_enqueueMessage = (DataMessage message) {
        expect(message.streamId, STREAM_ID);
        expect(message.bytes, bytes);
        c.got();
      };
      streamQueueMock.bufferIndicator.markUnBuffered();

      // TODO: Write tests for adding HeadersFrame/PushPromiseFrame.
    });

    test('connection-ignored-message-queue-in', () {
      const STREAM_ID = 99;
      final bytes = [1, 2, 3];

      var windowMock = new MockIncomingWindowHandler();
      var queue = new ConnectionMessageQueueIn(windowMock);

      // Insert a [DataFrame] and let it be buffered.
      var header = new FrameHeader(0, 0, 0, STREAM_ID);
      var c = new TestCounter();
      windowMock.mock_gotData = (int diff) {
        expect(diff, bytes.length);
        c.got();
      };
      queue.processIgnoredDataFrame(new DataFrame(header, 0, bytes));
      expect(queue.pendingMessages, 0);
    });
  });
}

class MockFrameWriter extends SmartMock implements FrameWriter {
  BufferIndicator bufferIndicator = new BufferIndicator();

  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}

class MockStreamMessageQueueIn extends SmartMock
                               implements StreamMessageQueueIn {
  BufferIndicator bufferIndicator = new BufferIndicator();

  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}

class MockIncomingWindowHandler extends SmartMock
                                implements IncomingWindowHandler {
  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}

class MockOutgoingWindowHandler extends SmartMock
                                implements OutgoingConnectionWindowHandler,
                                           OutgoingStreamWindowHandler {
  BufferIndicator positiveWindow = new BufferIndicator();
  int peerWindowSize = new Window().size;

  dynamic noSuchMethod(_) => super.noSuchMethod(_);
}
