// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO: Take priorities into account.
// TODO: Properly fragment large data frames, so they are not taking up too much
// bandwidth.

import 'dart:async';
import 'dart:collection';

import '../../transport.dart';
import '../byte_utils.dart';
import '../error_handler.dart';
import '../frames/frames.dart';
import 'queue_messages.dart';
import 'stream_queues.dart';
import 'window_handler.dart';

/// The last place before messages coming from the application get encoded and
/// send as [Frame]s.
///
/// It will convert [Message]s from higher layers and send them via [Frame]s.
///
/// - It will queue messages until the connection-level flow control window
///   allows sending the message and the underlying [StreamSink] is not
///   buffering.
/// - It will use a [FrameWriter] to write a new frame to the connection.
// TODO: Make [StreamsHandler] call [connectionOut.startClosing()] once
//   * all streams have been closed
//   * the connection state is finishing
class ConnectionMessageQueueOut extends Object
    with TerminatableMixin, ClosableMixin {
  /// The handler which will be used for increasing the connection-level flow
  /// control window.
  final OutgoingConnectionWindowHandler _connectionWindow;

  /// The buffered [Message]s which are to be delivered to the remote peer.
  final Queue<Message> _messages = Queue<Message>();

  /// The [FrameWriter] used for writing Headers/Data/PushPromise frames.
  final FrameWriter _frameWriter;

  ConnectionMessageQueueOut(this._connectionWindow, this._frameWriter) {
    _frameWriter.bufferIndicator.bufferEmptyEvents.listen((_) {
      _trySendMessages();
    });
    _connectionWindow.positiveWindow.bufferEmptyEvents.listen((_) {
      _trySendMessages();
    });
  }

  /// The number of pending messages which haven't been written to the wire.
  int get pendingMessages => _messages.length;

  /// Enqueues a new [Message] which should be delivered to the remote peer.
  void enqueueMessage(Message message) {
    ensureNotClosingSync(() {
      if (!wasTerminated) {
        _messages.addLast(message);
        if (message is! DataMessage) _nothingSendableWhileBlocked = false;
        _trySendMessages();
      }
    });
  }

  /// Drops the queued [DataMessage]s of the stream [streamId], which is about
  /// to be reset.
  ///
  /// Returns `true` if a [HeadersMessage] for [streamId] is still queued, i.e.
  /// has not been written to the [FrameWriter] yet. In that case the
  /// `RST_STREAM` must be enqueued behind it instead of being written directly:
  /// a `RST_STREAM` arriving before the `HEADERS` that open the stream is a
  /// connection error for the peer (RFC 9113 section 6.4: "RST_STREAM frames
  /// MUST NOT be sent for a stream in the "idle" state").
  bool cancelStreamMessages(int streamId) {
    _messages.removeWhere((m) => m is DataMessage && m.streamId == streamId);
    _nothingSendableWhileBlocked = false;
    return _messages.any((m) => m is HeadersMessage && m.streamId == streamId);
  }

  @override
  void onTerminated(Object? error) {
    _messages.clear();
    closeWithError(error);
  }

  @override
  void onCheckForClose() {
    if (isClosing && _messages.isEmpty) {
      closeWithValue();
    }
  }

  /// Set once a scan of [_messages] under an exhausted connection window has
  /// found nothing sendable.
  ///
  /// Enqueueing further [DataMessage]s cannot change that outcome, so the scan
  /// (which is linear in the queue length) is skipped until the queue changes
  /// in a way that could make a message sendable: a non-DATA message is
  /// enqueued, a message is sent, or a stream's messages are cancelled.
  /// Without this, every `sendData()` call made while the connection window is
  /// exhausted would rescan the whole queue, i.e. quadratic work.
  bool _nothingSendableWhileBlocked = false;

  /// The next message which can be written now, or `null` if none can.
  ///
  /// Normally that is the first queued message. When the connection-level send
  /// window is exhausted and the first message is a [DataMessage], frames which
  /// are not subject to flow control (RFC 9113 section 6.9: only DATA frames
  /// are) may still be written: `GOAWAY`, and `HEADERS` / `RST_STREAM` of
  /// streams that have no earlier queued message. Skipping a message of a
  /// stream blocks all later messages of that stream, so the per-stream frame
  /// order is preserved.
  Message? _peekSendableMessage() {
    if (_messages.isEmpty || _frameWriter.bufferIndicator.wouldBuffer) {
      return null;
    }
    final first = _messages.first;
    if (first is! DataMessage ||
        !_connectionWindow.positiveWindow.wouldBuffer) {
      return first;
    }
    if (_nothingSendableWhileBlocked) return null;

    final blockedStreams = <int>{};
    for (final message in _messages) {
      if (message is GoawayMessage) return message;
      if (message is DataMessage || blockedStreams.contains(message.streamId)) {
        blockedStreams.add(message.streamId);
      } else if (message is PushPromiseMessage) {
        // A PUSH_PROMISE must precede any frame of the promised stream and
        // the END_STREAM of its associated stream (RFC 9113 section 8.4.1);
        // keep it, and everything after it on both streams, in order.
        blockedStreams
          ..add(message.streamId)
          ..add(message.promisedStreamId);
      } else {
        return message;
      }
    }
    _nothingSendableWhileBlocked = true;
    return null;
  }

  void _trySendMessages() {
    if (!wasTerminated) {
      // We can make progress if
      //   * there is at least one message to send
      //   * the underlying frame writer / sink / socket doesn't block
      //   * either one
      //     * the next sendable message is a non-flow control message
      //     * the connection window is positive

      final message = _peekSendableMessage();
      if (message != null) {
        _trySendMessage(message);

        // If we have more messages and we can send them, we'll run them
        // using `Timer.run()` to let other things get in-between.
        if (_peekSendableMessage() != null) {
          // TODO: If all the frame writer methods would return the
          // number of bytes written, we could just say, we loop here until 10kb
          // and after words, we'll make `Timer.run()`.
          Timer.run(_trySendMessages);
        } else {
          onCheckForClose();
        }
      }
    }
  }

  void _trySendMessage(Message message) {
    if (identical(message, _messages.first)) {
      _messages.removeFirst();
    } else {
      _messages.remove(message);
    }
    _nothingSendableWhileBlocked = false;
    if (message is HeadersMessage) {
      _frameWriter.writeHeadersFrame(
        message.streamId,
        message.headers,
        endStream: message.endStream,
      );
    } else if (message is PushPromiseMessage) {
      _frameWriter.writePushPromiseFrame(
        message.streamId,
        message.promisedStreamId,
        message.headers,
      );
    } else if (message is DataMessage) {
      if (_connectionWindow.peerWindowSize >= message.bytes.length) {
        _connectionWindow.decreaseWindow(message.bytes.length);
        _frameWriter.writeDataFrame(
          message.streamId,
          message.bytes,
          endStream: message.endStream,
        );
      } else {
        // NOTE: We need to fragment the DataMessage.
        // TODO: Do not fragment if the number of bytes we can send is too low
        var len = _connectionWindow.peerWindowSize;
        var head = viewOrSublist(message.bytes, 0, len);
        var tail = viewOrSublist(
          message.bytes,
          len,
          message.bytes.length - len,
        );

        _connectionWindow.decreaseWindow(head.length);
        _frameWriter.writeDataFrame(message.streamId, head, endStream: false);

        var tailMessage = DataMessage(
          message.streamId,
          tail,
          message.endStream,
        );
        _messages.addFirst(tailMessage);
      }
    } else if (message is ResetStreamMessage) {
      _frameWriter.writeRstStreamFrame(message.streamId, message.errorCode);
    } else if (message is GoawayMessage) {
      _frameWriter.writeGoawayFrame(
        message.lastStreamId,
        message.errorCode,
        message.debugData,
      );
    } else {
      throw StateError('Unexpected message in queue: ${message.runtimeType}');
    }
  }
}

/// The first place an incoming stream message gets delivered to.
///
/// The [ConnectionMessageQueueIn] will be given [Frame]s which were sent to
/// any stream on this connection.
///
/// - It will extract the necessary data from the [Frame] and store it in a new
///   [Message] object.
/// - It will multiplex the created [Message]es to a stream-specific
///   [StreamMessageQueueIn].
/// - If the [StreamMessageQueueIn] cannot accept more data, the data will be
///   buffered until it can.
/// - [DataMessage]s which have been successfully delivered to a stream-specific
///   [StreamMessageQueueIn] will increase the flow control window for the
///   connection.
///
/// Incoming [DataFrame]s will decrease the flow control window the peer has
/// available.
// TODO: Make [StreamsHandler] call [connectionOut.startClosing()] once
//   * all streams have been closed
//   * the connection state is finishing
class ConnectionMessageQueueIn extends Object
    with TerminatableMixin, ClosableMixin {
  /// The handler which will be used for increasing the connection-level flow
  /// control window.
  final IncomingWindowHandler _windowUpdateHandler;

  /// Catches any protocol errors and acts upon them.
  final void Function(void Function()) _catchProtocolErrors;

  /// A mapping from stream-id to the corresponding stream-specific
  /// [StreamMessageQueueIn].
  final Map<int, StreamMessageQueueIn> _stream2messageQueue = {};

  /// A buffer for [Message]s which cannot be received by their
  /// [StreamMessageQueueIn].
  final Map<int, Queue<Message>> _stream2pendingMessages = {};

  /// The number of pending messages which haven't been delivered
  /// to the stream-specific queue. (for debugging purposes)
  int _count = 0;

  ConnectionMessageQueueIn(
    this._windowUpdateHandler,
    this._catchProtocolErrors,
  );

  @override
  void onTerminated(Object? error) {
    for (final mq in _stream2messageQueue.values) {
      mq.terminate(error);
    }
    _stream2messageQueue.clear();
    _stream2pendingMessages.clear();
    closeWithError(error);
  }

  @override
  void onCheckForClose() {
    if (isClosing) {
      assert(_stream2messageQueue.isEmpty == _stream2pendingMessages.isEmpty);
      if (_stream2messageQueue.isEmpty) {
        closeWithValue();
      }
    }
  }

  /// The number of pending messages which haven't been delivered
  /// to the stream-specific queue. (for debugging purposes)
  int get pendingMessages => _count;

  /// Registers a stream specific [StreamMessageQueueIn] for a new stream id.
  void insertNewStreamMessageQueue(int streamId, StreamMessageQueueIn mq) {
    if (_stream2messageQueue.containsKey(streamId)) {
      throw ArgumentError(
        'Cannot register a SteramMessageQueueIn for the same streamId '
        'multiple times',
      );
    }

    var pendingMessages = Queue<Message>();
    _stream2pendingMessages[streamId] = pendingMessages;
    _stream2messageQueue[streamId] = mq;

    mq.bufferIndicator.bufferEmptyEvents.listen((_) {
      _catchProtocolErrors(() {
        _tryDispatch(streamId, mq, pendingMessages);
      });
    });
  }

  /// Removes a stream id and its message queue from this connection-level
  /// message queue.
  ///
  /// Buffered [DataMessage]s that were never delivered to the stream still
  /// count against the connection receive window (RFC 9113 section 6.9.1), so
  /// the window is replenished for them - unless [replenishWindow] is `false`,
  /// which callers pass while the connection is being torn down and nothing
  /// can be written to the peer any more.
  void removeStreamMessageQueue(int streamId, {bool replenishWindow = true}) {
    final pendingMessages = _stream2pendingMessages.remove(streamId);
    _stream2messageQueue.remove(streamId);
    if (pendingMessages != null) {
      var ignoredBytes = 0;
      for (final message in pendingMessages) {
        _count--;
        if (message is DataMessage) {
          ignoredBytes += message.bytes.length;
        }
      }
      if (replenishWindow && ignoredBytes > 0) {
        _windowUpdateHandler.dataProcessed(ignoredBytes);
      }
    }
  }

  /// Processes an incoming [DataFrame] which is addressed to a specific stream.
  void processDataFrame(DataFrame frame) {
    var streamId = frame.header.streamId;
    var message = DataMessage(streamId, frame.bytes, frame.hasEndStreamFlag);

    _windowUpdateHandler.gotData(message.bytes.length);
    _addMessage(streamId, message);
  }

  /// If a [DataFrame] will be ignored, this method will take the minimal
  /// action necessary.
  void processIgnoredDataFrame(DataFrame frame) {
    _windowUpdateHandler.dataProcessed(frame.bytes.length);
  }

  /// Processes an incoming [HeadersFrame] which is addressed to a specific
  /// stream.
  void processHeadersFrame(HeadersFrame frame) {
    var streamId = frame.header.streamId;
    var message = HeadersMessage(
      streamId,
      frame.decodedHeaders,
      frame.hasEndStreamFlag,
    );
    // NOTE: Header frames do not affect flow control - only data frames do.
    _addMessage(streamId, message);
  }

  /// Processes an incoming [PushPromiseFrame] which is addressed to a specific
  /// stream.
  void processPushPromiseFrame(
    PushPromiseFrame frame,
    ClientTransportStream pushedStream,
  ) {
    var streamId = frame.header.streamId;
    var message = PushPromiseMessage(
      streamId,
      frame.decodedHeaders,
      frame.promisedStreamId,
      pushedStream,
      false,
    );

    // NOTE:
    //    * Header frames do not affect flow control - only data frames do.
    //    * At this point we might reorder a push message earlier than
    //      data/headers messages.
    _addPushMessage(streamId, message);
  }

  void _addMessage(int streamId, Message message) {
    _count++;

    // TODO: Do we need to do a runtime check here and
    // raise a protocol error if we cannot find the registered stream?
    var streamMQ = _stream2messageQueue[streamId]!;
    var pendingMessages = _stream2pendingMessages[streamId]!;
    pendingMessages.addLast(message);
    _tryDispatch(streamId, streamMQ, pendingMessages);
  }

  void _addPushMessage(int streamId, PushPromiseMessage message) {
    _count++;

    // TODO: Do we need to do a runtime check here and
    // raise a protocol error if we cannot find the registered stream?
    var streamMQ = _stream2messageQueue[streamId]!;
    streamMQ.enqueueMessage(message);
  }

  void _tryDispatch(
    int streamId,
    StreamMessageQueueIn mq,
    Queue<Message> pendingMessages,
  ) {
    var bytesDeliveredToStream = 0;
    while (!mq.bufferIndicator.wouldBuffer && pendingMessages.isNotEmpty) {
      _count--;

      var message = pendingMessages.removeFirst();
      if (message is DataMessage) {
        bytesDeliveredToStream += message.bytes.length;
      }
      mq.enqueueMessage(message);
      if (message.endStream) {
        assert(pendingMessages.isEmpty);

        _stream2messageQueue.remove(streamId);
        _stream2pendingMessages.remove(streamId);
      }
    }
    if (bytesDeliveredToStream > 0) {
      _windowUpdateHandler.dataProcessed(bytesDeliveredToStream);
    }

    onCheckForClose();
  }

  /// Flushes all pending messages for [streamId] to its [StreamMessageQueueIn],
  /// even if the stream queue is currently buffering (e.g. when a peer sends
  /// `RST_STREAM(NO_ERROR)` after a complete response).
  void forceDispatchStreamMessages(int streamId) {
    final pendingMessages = _stream2pendingMessages[streamId];
    final mq = _stream2messageQueue[streamId];
    if (pendingMessages == null || mq == null) return;
    var bytesDeliveredToStream = 0;
    while (pendingMessages.isNotEmpty) {
      _count--;
      final message = pendingMessages.removeFirst();
      if (message is DataMessage) {
        bytesDeliveredToStream += message.bytes.length;
      }
      mq.enqueueMessage(message);
      if (message.endStream) {
        _stream2messageQueue.remove(streamId);
        _stream2pendingMessages.remove(streamId);
        break;
      }
    }
    if (bytesDeliveredToStream > 0) {
      _windowUpdateHandler.dataProcessed(bytesDeliveredToStream);
    }
    onCheckForClose();
  }

  void forceDispatchIncomingMessages() {
    final toBeRemoved = <int>{};
    _stream2pendingMessages.forEach((int streamId, Queue<Message> messages) {
      final mq = _stream2messageQueue[streamId]!;
      while (messages.isNotEmpty) {
        _count--;
        final message = messages.removeFirst();
        mq.enqueueMessage(message);
        if (message.endStream) {
          toBeRemoved.add(streamId);
          break;
        }
      }
    });

    for (final streamId in toBeRemoved) {
      _stream2messageQueue.remove(streamId);
      _stream2pendingMessages.remove(streamId);
    }
  }
}
