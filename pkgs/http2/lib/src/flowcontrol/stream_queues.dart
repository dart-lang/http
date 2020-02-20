// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import '../../transport.dart';
import '../async_utils/async_utils.dart';
import '../byte_utils.dart';
import '../error_handler.dart';

import 'connection_queues.dart';
import 'queue_messages.dart';
import 'window_handler.dart';

/// This class will buffer any headers/data messages in the order they were
/// added.
///
/// It will ensure that we never send more data than the remote flow control
/// window allows.
class StreamMessageQueueOut extends Object
    with TerminatableMixin, ClosableMixin {
  /// The id of the stream this message queue belongs to.
  final int streamId;

  /// The stream-level flow control handler.
  final OutgoingStreamWindowHandler streamWindow;

  /// The underlying connection-level message queue.
  final ConnectionMessageQueueOut connectionMessageQueue;

  /// A indicator for whether this queue is currently buffering.
  final BufferIndicator bufferIndicator = BufferIndicator();

  /// Buffered [Message]s which will be written to the underlying connection
  /// if the flow control window allows so.
  final Queue<Message> _messages = Queue<Message>();

  /// Debugging data on how much data should be written to the underlying
  /// connection message queue.
  int toBeWrittenBytes = 0;

  /// Debugging data on how much data was written to the underlying connection
  /// message queue.
  int writtenBytes = 0;

  StreamMessageQueueOut(
      this.streamId, this.streamWindow, this.connectionMessageQueue) {
    streamWindow.positiveWindow.bufferEmptyEvents.listen((_) {
      if (!wasTerminated) {
        _trySendData();
      }
    });
    if (streamWindow.positiveWindow.wouldBuffer) {
      bufferIndicator.markBuffered();
    } else {
      bufferIndicator.markUnBuffered();
    }
  }

  /// Debugging data about how many messages are pending to be written to the
  /// connection message queue.
  int get pendingMessages => _messages.length;

  /// Enqueues a new [Message] which is to be delivered to the connection
  /// message queue.
  void enqueueMessage(Message message) {
    if (message is! ResetStreamMessage) ensureNotClosingSync(() {});
    if (!wasTerminated) {
      if (message.endStream) startClosing();

      if (message is DataMessage) {
        toBeWrittenBytes += message.bytes.length;
      }

      _messages.addLast(message);
      _trySendData();

      if (_messages.isNotEmpty) {
        bufferIndicator.markBuffered();
      }
    }
  }

  @override
  void onTerminated(error) {
    _messages.clear();
    closeWithError(error);
  }

  @override
  void onCheckForClose() {
    if (isClosing && _messages.isEmpty) closeWithValue();
  }

  void _trySendData() {
    var queueLenBefore = _messages.length;

    while (_messages.isNotEmpty) {
      var message = _messages.first;

      if (message is HeadersMessage) {
        _messages.removeFirst();
        connectionMessageQueue.enqueueMessage(message);
      } else if (message is DataMessage) {
        var bytesAvailable = streamWindow.peerWindowSize;
        if (bytesAvailable > 0 || message.bytes.isEmpty) {
          _messages.removeFirst();

          // Do we need to fragment?
          var messageToSend = message;
          var messageBytes = message.bytes;
          // TODO: Do not fragment if the number of bytes we can send is too low
          if (messageBytes.length > bytesAvailable) {
            var partA = viewOrSublist(messageBytes, 0, bytesAvailable);
            var partB = viewOrSublist(messageBytes, bytesAvailable,
                messageBytes.length - bytesAvailable);
            var messageA = DataMessage(message.streamId, partA, false);
            var messageB =
                DataMessage(message.streamId, partB, message.endStream);

            // Put the second fragment back into the front of the queue.
            _messages.addFirst(messageB);

            // Send the first fragment.
            messageToSend = messageA;
          }

          writtenBytes += messageToSend.bytes.length;
          streamWindow.decreaseWindow(messageToSend.bytes.length);
          connectionMessageQueue.enqueueMessage(messageToSend);
        } else {
          break;
        }
      } else if (message is ResetStreamMessage) {
        _messages.removeFirst();
        connectionMessageQueue.enqueueMessage(message);
      } else {
        throw StateError('Unknown messages type: ${message.runtimeType}');
      }
    }
    if (queueLenBefore > 0 && _messages.isEmpty) {
      bufferIndicator.markUnBuffered();
    }

    onCheckForClose();
  }
}

/// Keeps a list of [Message] which should be delivered to the
/// [TransportStream].
///
/// It will keep messages up to the stream flow control window size if the
/// [messages] listener is paused.
class StreamMessageQueueIn extends Object
    with TerminatableMixin, ClosableMixin, CancellableMixin {
  /// The stream-level window our peer is using when sending us messages.
  final IncomingWindowHandler windowHandler;

  /// A indicator whether this [StreamMessageQueueIn] is currently buffering.
  final BufferIndicator bufferIndicator = BufferIndicator();

  /// The pending [Message]s which are to be delivered via the [messages]
  /// stream.
  final Queue<Message> _pendingMessages = Queue<Message>();

  /// The [StreamController] used for producing the [messages] stream.
  StreamController<StreamMessage> _incomingMessagesC;

  /// The [StreamController] used for producing the [serverPushes] stream.
  StreamController<TransportStreamPush> _serverPushStreamsC;

  StreamMessageQueueIn(this.windowHandler) {
    // We start by marking it as buffered, since no one is listening yet and
    // incoming messages will get buffered.
    bufferIndicator.markBuffered();

    _incomingMessagesC = StreamController(
        onListen: () {
          if (!wasClosed && !wasTerminated) {
            _tryDispatch();
            _tryUpdateBufferIndicator();
          }
        },
        onPause: () {
          _tryUpdateBufferIndicator();
          // TODO: Would we ever want to decrease the window size in this
          // situation?
        },
        onResume: () {
          if (!wasClosed && !wasTerminated) {
            _tryDispatch();
            _tryUpdateBufferIndicator();
          }
        },
        onCancel: cancel);

    _serverPushStreamsC = StreamController(onListen: () {
      if (!wasClosed && !wasTerminated) {
        _tryDispatch();
        _tryUpdateBufferIndicator();
      }
    });
  }

  /// Debugging data: the number of pending messages in this queue.
  int get pendingMessages => _pendingMessages.length;

  /// The stream of [StreamMessage]s which come from the remote peer.
  Stream<StreamMessage> get messages => _incomingMessagesC.stream;

  /// The stream of [TransportStreamPush]es which come from the remote peer.
  Stream<TransportStreamPush> get serverPushes => _serverPushStreamsC.stream;

  /// A lower layer enqueues a new [Message] which should be delivered to the
  /// app.
  void enqueueMessage(Message message) {
    ensureNotClosingSync(() {
      if (!wasTerminated) {
        if (message is PushPromiseMessage) {
          // NOTE: If server pushes were enabled, the client is responsible for
          // either rejecting or handling them.
          assert(!_serverPushStreamsC.isClosed);
          var transportStreamPush =
              TransportStreamPush(message.headers, message.pushedStream);
          _serverPushStreamsC.add(transportStreamPush);
          return;
        }

        if (message is DataMessage) {
          windowHandler.gotData(message.bytes.length);
        }
        _pendingMessages.add(message);
        if (message.endStream) startClosing();

        _tryDispatch();
        _tryUpdateBufferIndicator();
      }
    });
  }

  @override
  void onTerminated(exception) {
    _pendingMessages.clear();
    if (!wasClosed) {
      if (exception != null) {
        _incomingMessagesC.addError(exception);
      }
      _incomingMessagesC.close();
      _serverPushStreamsC.close();
      closeWithError(exception);
    }
  }

  void onCloseCheck() {
    if (isClosing && !wasClosed && _pendingMessages.isEmpty) {
      _incomingMessagesC.close();
      _serverPushStreamsC.close();
      closeWithValue();
    }
  }

  void forceDispatchIncomingMessages() {
    while (_pendingMessages.isNotEmpty) {
      final message = _pendingMessages.removeFirst();
      assert(!_incomingMessagesC.isClosed);
      if (message is HeadersMessage) {
        _incomingMessagesC.add(HeadersStreamMessage(message.headers,
            endStream: message.endStream));
      } else if (message is DataMessage) {
        if (message.bytes.isNotEmpty) {
          _incomingMessagesC.add(
              DataStreamMessage(message.bytes, endStream: message.endStream));
        }
      } else {
        // This can never happen.
        assert(false);
      }
      if (message.endStream) {
        onCloseCheck();
      }
    }
  }

  void _tryDispatch() {
    while (!wasTerminated && _pendingMessages.isNotEmpty) {
      var handled = wasCancelled;

      var message = _pendingMessages.first;
      if (wasCancelled) {
        _pendingMessages.removeFirst();
      } else if (message is HeadersMessage || message is DataMessage) {
        assert(!_incomingMessagesC.isClosed);
        if (_incomingMessagesC.hasListener && !_incomingMessagesC.isPaused) {
          _pendingMessages.removeFirst();
          if (message is HeadersMessage) {
            // NOTE: Header messages do not affect flow control - only
            // data messages do.
            _incomingMessagesC.add(HeadersStreamMessage(message.headers,
                endStream: message.endStream));
          } else if (message is DataMessage) {
            if (message.bytes.isNotEmpty) {
              _incomingMessagesC.add(DataStreamMessage(message.bytes,
                  endStream: message.endStream));
              windowHandler.dataProcessed(message.bytes.length);
            }
          } else {
            // This can never happen.
            assert(false);
          }
          handled = true;
        }
      }
      if (handled) {
        if (message.endStream) {
          onCloseCheck();
        }
      } else {
        break;
      }
    }
  }

  void _tryUpdateBufferIndicator() {
    if (_incomingMessagesC.isPaused || _pendingMessages.isNotEmpty) {
      bufferIndicator.markBuffered();
    } else if (bufferIndicator.wouldBuffer && !_incomingMessagesC.isPaused) {
      bufferIndicator.markUnBuffered();
    }
  }
}
