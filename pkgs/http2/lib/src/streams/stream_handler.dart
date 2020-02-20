// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import '../../transport.dart';

import '../connection.dart';
import '../error_handler.dart';
import '../flowcontrol/connection_queues.dart';
import '../flowcontrol/queue_messages.dart';
import '../flowcontrol/stream_queues.dart';
import '../flowcontrol/window.dart';
import '../flowcontrol/window_handler.dart';
import '../frames/frames.dart';
import '../hpack/hpack.dart';
import '../settings/settings.dart';
import '../sync_errors.dart';

/// Represents the current state of a stream.
enum StreamState {
  ReservedLocal,
  ReservedRemote,
  Idle,
  Open,
  HalfClosedLocal,
  HalfClosedRemote,
  Closed,

  /// The [Terminated] state is an artificial state and signals that this stream
  /// has been forcefully terminated.
  Terminated,
}

/// Represents a HTTP/2 stream.
class Http2StreamImpl extends TransportStream
    implements ClientTransportStream, ServerTransportStream {
  /// The id of this stream.
  ///
  ///   * odd numbered streams are client streams
  ///   * even numbered streams are opened from the server
  @override
  final int id;

  // The queue for incoming [StreamMessage]s.
  final StreamMessageQueueIn incomingQueue;

  // The queue for outgoing [StreamMessage]s.
  final StreamMessageQueueOut outgoingQueue;

  // The stream controller to which the application can
  // add outgoing messages.
  final StreamController<StreamMessage> _outgoingC;

  final OutgoingStreamWindowHandler windowHandler;

  // The state of this stream.
  StreamState state = StreamState.Idle;

  // Error code from RST_STREAM frame, if the stream has been terminated
  // remotely.
  int _terminatedErrorCode;

  // Termination handler. Invoked if the stream receives an RST_STREAM frame.
  void Function(int) _onTerminated;

  final ZoneUnaryCallback<bool, Http2StreamImpl> _canPushFun;
  final ZoneBinaryCallback<ServerTransportStream, Http2StreamImpl, List<Header>>
      _pushStreamFun;
  final ZoneUnaryCallback<dynamic, Http2StreamImpl> _terminateStreamFun;

  StreamSubscription _outgoingCSubscription;

  Http2StreamImpl(
      this.incomingQueue,
      this.outgoingQueue,
      this._outgoingC,
      this.id,
      this.windowHandler,
      this._canPushFun,
      this._pushStreamFun,
      this._terminateStreamFun);

  /// A stream of data and/or headers from the remote end.
  @override
  Stream<StreamMessage> get incomingMessages => incomingQueue.messages;

  /// A sink for writing data and/or headers to the remote end.
  @override
  StreamSink<StreamMessage> get outgoingMessages => _outgoingC.sink;

  /// Streams which the server pushed to this endpoint.
  @override
  Stream<TransportStreamPush> get peerPushes => incomingQueue.serverPushes;

  @override
  bool get canPush => _canPushFun(this);

  /// Pushes a new stream to a client.
  ///
  /// The [requestHeaders] are the headers to which the pushed stream
  /// responds to.
  @override
  ServerTransportStream push(List<Header> requestHeaders) =>
      _pushStreamFun(this, requestHeaders);

  @override
  void terminate() => _terminateStreamFun(this);

  @override
  set onTerminated(void Function(int) handler) {
    _onTerminated = handler;
    if (_terminatedErrorCode != null && _onTerminated != null) {
      _onTerminated(_terminatedErrorCode);
    }
  }

  void _handleTerminated(int errorCode) {
    _terminatedErrorCode = errorCode;
    if (_onTerminated != null) {
      _onTerminated(_terminatedErrorCode);
    }
  }
}

/// Handles [Frame]s with a non-zero stream-id.
///
/// It keeps track of open streams, their state, their queues, forwards
/// messages from the connection level to stream level and vise versa.
// TODO: Handle stream/connection queue errors & forward to connection object.
class StreamHandler extends Object with TerminatableMixin, ClosableMixin {
  static const int MAX_STREAM_ID = (1 << 31) - 1;

  final FrameWriter _frameWriter;
  final ConnectionMessageQueueIn incomingQueue;
  final ConnectionMessageQueueOut outgoingQueue;

  final StreamController<TransportStream> _newStreamsC = StreamController();

  final ActiveSettings _peerSettings;
  final ActiveSettings _localSettings;

  final Map<int, Http2StreamImpl> _openStreams = {};
  int nextStreamId;
  int lastRemoteStreamId;

  int _highestStreamIdReceived = 0;

  /// Represents the highest stream id this connection has received from the
  /// remote side.
  int get highestPeerInitiatedStream => _highestStreamIdReceived;

  bool get isServer => nextStreamId.isEven;

  bool get ranOutOfStreamIds => _ranOutOfStreamIds();

  /// Whether it is possible to open a new stream to the remote end (e.g. based
  /// on whether we have reached the limit of maximum concurrent open streams).
  bool get canOpenStream => _canCreateNewStream();

  final ActiveStateHandler _onActiveStateChanged;

  StreamHandler._(
      this._frameWriter,
      this.incomingQueue,
      this.outgoingQueue,
      this._peerSettings,
      this._localSettings,
      this._onActiveStateChanged,
      this.nextStreamId,
      this.lastRemoteStreamId);

  factory StreamHandler.client(
      FrameWriter writer,
      ConnectionMessageQueueIn incomingQueue,
      ConnectionMessageQueueOut outgoingQueue,
      ActiveSettings peerSettings,
      ActiveSettings localSettings,
      ActiveStateHandler onActiveStateChanged) {
    return StreamHandler._(writer, incomingQueue, outgoingQueue, peerSettings,
        localSettings, onActiveStateChanged, 1, 0);
  }

  factory StreamHandler.server(
      FrameWriter writer,
      ConnectionMessageQueueIn incomingQueue,
      ConnectionMessageQueueOut outgoingQueue,
      ActiveSettings peerSettings,
      ActiveSettings localSettings,
      ActiveStateHandler onActiveStateChanged) {
    return StreamHandler._(writer, incomingQueue, outgoingQueue, peerSettings,
        localSettings, onActiveStateChanged, 2, -1);
  }

  @override
  void onTerminated(exception) {
    _openStreams.values.toList().forEach((stream) =>
        _closeStreamAbnormally(stream, exception, propagateException: true));
    startClosing();
  }

  void forceDispatchIncomingMessages() {
    _openStreams.forEach((int streamId, Http2StreamImpl stream) {
      stream.incomingQueue.forceDispatchIncomingMessages();
    });
  }

  Stream<TransportStream> get incomingStreams => _newStreamsC.stream;

  List<TransportStream> get openStreams => _openStreams.values.toList();

  void processInitialWindowSizeSettingChange(int difference) {
    // If the initialFlowWindow size was changed via a SettingsFrame, all
    // existing streams must be updated to reflect this change.
    _openStreams.values.forEach((Http2StreamImpl stream) {
      stream.windowHandler.processInitialWindowSizeSettingChange(difference);
    });
  }

  void processGoawayFrame(GoawayFrame frame) {
    var lastStreamId = frame.lastStreamId;
    var streamIds = _openStreams.keys
        .where((id) => id > lastStreamId && !_isPeerInitiatedStream(id))
        .toList();
    for (var id in streamIds) {
      var exception = StreamException(
          id,
          'Remote end was telling us to stop. This stream was not processed '
          'and can therefore be retried (on a new connection).');
      _closeStreamIdAbnormally(id, exception, propagateException: true);
    }
  }

  ////////////////////////////////////////////////////////////////////////////
  //// New local/remote Stream handling
  ////////////////////////////////////////////////////////////////////////////

  bool _isPeerInitiatedStream(int streamId) {
    var isServerStreamId = streamId.isEven;
    var isLocalStream = isServerStreamId == isServer;
    return !isLocalStream;
  }

  Http2StreamImpl newStream(List<Header> headers, {bool endStream = false}) {
    return ensureNotTerminatedSync(() {
      var stream = newLocalStream();
      _sendHeaders(stream, headers, endStream: endStream);
      return stream;
    });
  }

  Http2StreamImpl newLocalStream() {
    return ensureNotTerminatedSync(() {
      assert(_canCreateNewStream());

      if (MAX_STREAM_ID < nextStreamId) {
        throw StateError(
            'Cannot create new streams, since a wrap around would happen.');
      }
      var streamId = nextStreamId;
      nextStreamId += 2;
      return _newStreamInternal(streamId);
    });
  }

  Http2StreamImpl newRemoteStream(int remoteStreamId) {
    return ensureNotTerminatedSync(() {
      assert(remoteStreamId <= MAX_STREAM_ID);
      // NOTE: We cannot enforce that a new stream id is 2 higher than the last
      // used stream id. Meaning there can be "holes" in the sense that stream
      // ids are not used:
      //
      // http/2 spec:
      //   The first use of a new stream identifier implicitly closes all
      //   streams in the "idle" state that might have been initiated by that
      //   peer with a lower-valued stream identifier.  For example, if a client
      //   sends a HEADERS frame on stream 7 without ever sending a frame on
      //   stream 5, then stream 5 transitions to the "closed" state when the
      //   first frame for stream 7 is sent or received.

      if (remoteStreamId <= lastRemoteStreamId) {
        throw ProtocolException('Remote tried to open new stream which is '
            'not in "idle" state.');
      }

      var sameDirection = (nextStreamId + remoteStreamId) % 2 == 0;
      assert(!sameDirection);

      lastRemoteStreamId = remoteStreamId;
      return _newStreamInternal(remoteStreamId);
    });
  }

  Http2StreamImpl _newStreamInternal(int streamId) {
    // For each new stream we must:
    //   - setup sending/receiving [Window]s with correct initial size
    //   - setup sending/receiving WindowHandlers which take care of
    //     updating the windows.
    //   - setup incoming/outgoing stream queues, which buffer data
    //     that is not handled by
    //       * the application [incoming]
    //       * the underlying transport [outgoing]
    //   - register incoming stream queue in connection-level queue

    var outgoingStreamWindow =
        Window(initialSize: _peerSettings.initialWindowSize);

    var incomingStreamWindow =
        Window(initialSize: _localSettings.initialWindowSize);

    var windowOutHandler = OutgoingStreamWindowHandler(outgoingStreamWindow);

    var windowInHandler = IncomingWindowHandler.stream(
        _frameWriter, incomingStreamWindow, streamId);

    var streamQueueIn = StreamMessageQueueIn(windowInHandler);
    var streamQueueOut =
        StreamMessageQueueOut(streamId, windowOutHandler, outgoingQueue);

    incomingQueue.insertNewStreamMessageQueue(streamId, streamQueueIn);

    var _outgoingC = StreamController<StreamMessage>();
    var stream = Http2StreamImpl(streamQueueIn, streamQueueOut, _outgoingC,
        streamId, windowOutHandler, _canPush, _push, _terminateStream);
    final wasIdle = _openStreams.isEmpty;
    _openStreams[stream.id] = stream;

    _setupOutgoingMessageHandling(stream);

    // Handle incoming stream cancellation. RST is only sent when streamQueueOut
    // has been closed because RST make the stream 'closed'.
    streamQueueIn.onCancel.then((_) {
      // If our side is done sending data, i.e. we have enqueued the
      // end-of-stream in the outgoing message queue, but the remote end is
      // still sending us data, despite us not being interested in it, we will
      // reset the stream.
      if (stream.state == StreamState.HalfClosedLocal) {
        stream.outgoingQueue
            .enqueueMessage(ResetStreamMessage(stream.id, ErrorCode.CANCEL));
      }
    });

    // NOTE: We are not interested whether the streams were normally finished
    // or abnormally terminated. Therefore we use 'catchError((_) {})'!
    var streamDone = [streamQueueIn.done, streamQueueOut.done];
    Future.wait(streamDone).catchError((_) {}).whenComplete(() {
      _cleanupClosedStream(stream);
    });

    if (wasIdle) {
      _onActiveStateChanged(true);
    }

    return stream;
  }

  bool _canPush(Http2StreamImpl stream) {
    var openState = (stream.state == StreamState.Open ||
        stream.state == StreamState.HalfClosedRemote);
    var pushEnabled = _peerSettings.enablePush;
    return openState &&
        pushEnabled &&
        _canCreateNewStream() &&
        !_ranOutOfStreamIds();
  }

  ServerTransportStream _push(
      Http2StreamImpl stream, List<Header> requestHeaders) {
    if (stream.state != StreamState.Open &&
        stream.state != StreamState.HalfClosedRemote) {
      throw StateError('Cannot push based on a stream that is neither open '
          'nor half-closed-remote.');
    }

    if (!_peerSettings.enablePush) {
      throw StateError('Client did disable server pushes.');
    }

    if (!_canCreateNewStream()) {
      throw StateError('Maximum number of streams reached.');
    }

    if (_ranOutOfStreamIds()) {
      throw StateError('There are no more stream ids left. Please use a '
          'new connection.');
    }

    var pushStream = newLocalStream();

    // NOTE: Since there was no real request from the client, we simulate it
    // by adding a synthetic `endStream = true` Data message into the incoming
    // queue.
    _changeState(pushStream, StreamState.ReservedLocal);
    // TODO: We should wait for us to send the headers frame before doing this
    // transition.
    _changeState(pushStream, StreamState.HalfClosedRemote);
    pushStream.incomingQueue
        .enqueueMessage(DataMessage(stream.id, const <int>[], true));

    _frameWriter.writePushPromiseFrame(
        stream.id, pushStream.id, requestHeaders);

    return pushStream;
  }

  void _terminateStream(Http2StreamImpl stream) {
    if (stream.state == StreamState.Open ||
        stream.state == StreamState.HalfClosedLocal ||
        stream.state == StreamState.HalfClosedRemote ||
        stream.state == StreamState.ReservedLocal ||
        stream.state == StreamState.ReservedRemote) {
      _frameWriter.writeRstStreamFrame(stream.id, ErrorCode.CANCEL);
      _closeStreamAbnormally(stream, null, propagateException: false);
    }
  }

  void _setupOutgoingMessageHandling(Http2StreamImpl stream) {
    stream._outgoingCSubscription =
        stream._outgoingC.stream.listen((StreamMessage msg) {
      if (!wasTerminated) {
        _handleNewOutgoingMessage(stream, msg);
      }
    }, onError: (error, stack) {
      if (!wasTerminated) {
        stream.terminate();
      }
    }, onDone: () {
      if (!wasTerminated) {
        // Stream should already have been closed by the last frame, but we
        // allow multiple close calls, just to make sure.
        _handleOutgoingClose(stream);
      }
    });
    stream.outgoingQueue.bufferIndicator.bufferEmptyEvents.listen((_) {
      if (stream._outgoingCSubscription.isPaused) {
        stream._outgoingCSubscription.resume();
      }
    });
  }

  void _handleNewOutgoingMessage(Http2StreamImpl stream, StreamMessage msg) {
    if (stream.state == StreamState.Idle) {
      if (msg is! HeadersStreamMessage) {
        var exception = TransportException(
            'The first message on a stream needs to be a headers frame.');
        _closeStreamAbnormally(stream, exception);
        return;
      }
      _changeState(stream, StreamState.Open);
    }

    if (msg is DataStreamMessage) {
      _sendData(stream, msg.bytes, endStream: msg.endStream);
    } else if (msg is HeadersStreamMessage) {
      _sendHeaders(stream, msg.headers, endStream: msg.endStream);
    }

    if (stream.outgoingQueue.bufferIndicator.wouldBuffer &&
        !stream._outgoingCSubscription.isPaused) {
      stream._outgoingCSubscription.pause();
    }
  }

  void _handleOutgoingClose(Http2StreamImpl stream) {
    // We allow multiple close calls.
    if (stream.state != StreamState.HalfClosedLocal &&
        stream.state != StreamState.Closed &&
        stream.state != StreamState.Terminated) {
      _sendData(stream, const [], endStream: true);
    }
  }

  ////////////////////////////////////////////////////////////////////////////
  //// Process incoming stream frames
  ////////////////////////////////////////////////////////////////////////////

  void processStreamFrame(ConnectionState connectionState, Frame frame) {
    try {
      _processStreamFrameInternal(connectionState, frame);
    } on StreamClosedException catch (exception) {
      _frameWriter.writeRstStreamFrame(
          exception.streamId, ErrorCode.STREAM_CLOSED);
      _closeStreamIdAbnormally(exception.streamId, exception);
    } on StreamException catch (exception) {
      _frameWriter.writeRstStreamFrame(
          exception.streamId, ErrorCode.INTERNAL_ERROR);
      _closeStreamIdAbnormally(exception.streamId, exception);
    }
  }

  void _processStreamFrameInternal(
      ConnectionState connectionState, Frame frame) {
    // If we initiated a close of the connection and the received frame belongs
    // to a stream id which is higher than the last peer-initiated stream we
    // processed, we'll ignore it.
    // http/2 spec:
    //     After sending a GOAWAY frame, the sender can discard frames for
    //     streams initiated by the receiver with identifiers higher than the
    //     identified last stream. However, any frames that alter connection
    //     state cannot be completely ignored. For instance, HEADERS,
    //     PUSH_PROMISE, and CONTINUATION frames MUST be minimally processed to
    //     ensure the state maintained for header compression is consistent
    //     (see Section 4.3); similarly, DATA frames MUST be counted toward
    //     the connection flow-control window. Failure to process these
    //     frames can cause flow control or header compression state to become
    //     unsynchronized.
    if (connectionState.activeFinishing &&
        _isPeerInitiatedStream(frame.header.streamId) &&
        frame.header.streamId > highestPeerInitiatedStream) {
      // Even if the frame will be ignored, we still need to process it in a
      // minimal way to ensure the connection window will be updated.
      if (frame is DataFrame) {
        incomingQueue.processIgnoredDataFrame(frame);
      }
      return null;
    }

    // TODO: Consider splitting this method into client/server handling.
    return ensureNotTerminatedSync(() {
      var stream = _openStreams[frame.header.streamId];
      if (stream == null) {
        bool frameBelongsToIdleStream() {
          var streamId = frame.header.streamId;
          var isServerStreamId = frame.header.streamId.isEven;
          var isLocalStream = isServerStreamId == isServer;
          var isIdleStream = isLocalStream
              ? streamId >= nextStreamId
              : streamId > lastRemoteStreamId;
          return isIdleStream;
        }

        if (_isPeerInitiatedStream(frame.header.streamId)) {
          // Update highest stream id we received and processed (we update it
          // before processing, so if it was an error, the client will not
          // retry it).
          _highestStreamIdReceived =
              max(_highestStreamIdReceived, frame.header.streamId);
        }

        if (frame is HeadersFrame) {
          if (isServer) {
            var newStream = newRemoteStream(frame.header.streamId);
            _changeState(newStream, StreamState.Open);

            _handleHeadersFrame(newStream, frame);
            _newStreamsC.add(newStream);
          } else {
            // A server cannot open new streams to the client. The only way
            // for a server to start a new stream is via a PUSH_PROMISE_FRAME.
            throw ProtocolException(
                'HTTP/2 clients cannot receive HEADER_FRAMEs as a connection'
                'attempt.');
          }
        } else if (frame is WindowUpdateFrame) {
          if (frameBelongsToIdleStream()) {
            // We treat this as a protocol error even though not enforced
            // or specified by the HTTP/2 spec.
            throw ProtocolException(
                'Got a WINDOW_UPDATE_FRAME for an "idle" stream id.');
          } else {
            // We must be able to receive window update frames for streams that
            // have been already closed. The specification does not mention
            // what happens if the streamId is belonging to an "idle" / unused
            // stream.
          }
        } else if (frame is RstStreamFrame) {
          if (frameBelongsToIdleStream()) {
            // [RstFrame]s for streams which haven't been established (known as
            // idle streams) must be treated as a connection error.
            throw ProtocolException(
                'Got a RST_STREAM_FRAME for an "idle" stream id.');
          } else {
            // [RstFrame]s for already dead (known as "closed") streams should
            // be ignored. (If the stream was in "HalfClosedRemote" and we did
            // send an endStream=true, it will be removed from the stream set).
          }
        } else if (frame is PriorityFrame) {
          // http/2 spec:
          //     The PRIORITY frame can be sent for a stream in the "idle" or
          //     "closed" states. This allows for the reprioritization of a
          //     group of dependent streams by altering the priority of an
          //     unused or closed parent stream.
          //
          // As long as we do not handle stream priorities, we can safely ignore
          // such frames on idle streams.
          //
          // NOTE: Firefox for example sends [PriorityFrame]s even without
          // opening any streams (e.g. streams 3,5,7,9,11 [PriorityFrame]s and
          // stream 13 is the first real stream opened by a [HeadersFrame].
          //
          // TODO: When implementing priorities for HTTP/2 streams, these frames
          // need to be taken into account.
        } else if (frame is PushPromiseFrame) {
          throw ProtocolException('Cannot push on a non-existent stream '
              '(stream ${frame.header.streamId} does not exist)');
        } else {
          throw StreamClosedException(
              frame.header.streamId,
              'No open stream found and was not a headers frame opening a '
              'new stream.');
        }
      } else {
        if (frame is HeadersFrame) {
          _handleHeadersFrame(stream, frame);
        } else if (frame is DataFrame) {
          _handleDataFrame(stream, frame);
        } else if (frame is PushPromiseFrame) {
          _handlePushPromiseFrame(stream, frame);
        } else if (frame is WindowUpdateFrame) {
          _handleWindowUpdate(stream, frame);
        } else if (frame is RstStreamFrame) {
          _handleRstFrame(stream, frame);
        } else {
          throw ProtocolException(
              'Unsupported frame type ${frame.runtimeType}.');
        }
      }
    });
  }

  void _handleHeadersFrame(Http2StreamImpl stream, HeadersFrame frame) {
    if (stream.state == StreamState.ReservedRemote) {
      _changeState(stream, StreamState.HalfClosedLocal);
    }

    if (stream.state != StreamState.Open &&
        stream.state != StreamState.HalfClosedLocal) {
      throw StreamClosedException(
          stream.id, 'Expected open state (was: ${stream.state}).');
    }

    incomingQueue.processHeadersFrame(frame);

    if (frame.hasEndStreamFlag) _handleEndOfStreamRemote(stream);
  }

  void _handleDataFrame(Http2StreamImpl stream, DataFrame frame) {
    if (stream.state != StreamState.Open &&
        stream.state != StreamState.HalfClosedLocal) {
      throw StreamClosedException(
          stream.id, 'Expected open state (was: ${stream.state}).');
    }

    incomingQueue.processDataFrame(frame);

    if (frame.hasEndStreamFlag) _handleEndOfStreamRemote(stream);
  }

  void _handlePushPromiseFrame(Http2StreamImpl stream, PushPromiseFrame frame) {
    if (stream.state != StreamState.Open &&
        stream.state != StreamState.HalfClosedLocal) {
      throw ProtocolException('Expected open state (was: ${stream.state}).');
    }

    var pushedStream = newRemoteStream(frame.promisedStreamId);
    _changeState(pushedStream, StreamState.ReservedRemote);

    incomingQueue.processPushPromiseFrame(frame, pushedStream);
  }

  void _handleWindowUpdate(Http2StreamImpl stream, WindowUpdateFrame frame) {
    stream.windowHandler.processWindowUpdate(frame);
  }

  void _handleRstFrame(Http2StreamImpl stream, RstStreamFrame frame) {
    stream._handleTerminated(frame.errorCode);
    var exception = StreamTransportException(
        'Stream was terminated by peer (errorCode: ${frame.errorCode}).');
    _closeStreamAbnormally(stream, exception, propagateException: true);
  }

  void _handleEndOfStreamRemote(Http2StreamImpl stream) {
    if (stream.state == StreamState.Open) {
      _changeState(stream, StreamState.HalfClosedRemote);
    } else if (stream.state == StreamState.HalfClosedLocal) {
      _changeState(stream, StreamState.Closed);
      // TODO: We have to make sure that we
      //   - remove the stream for data structures which only care about the
      //     state
      //   - keep the stream in data structures which need to be emptied
      //     (e.g. MessageQueues which are not empty yet).
      _openStreams.remove(stream.id);
    } else {
      throw StateError(
          'Got an end-of-stream from the remote end, but this stream is '
          'neither in the Open nor in the HalfClosedLocal state. '
          'This should never happen.');
    }
  }

  ////////////////////////////////////////////////////////////////////////////
  //// Process outgoing stream messages
  ////////////////////////////////////////////////////////////////////////////

  void _sendHeaders(Http2StreamImpl stream, List<Header> headers,
      {bool endStream = false}) {
    if (stream.state != StreamState.Idle &&
        stream.state != StreamState.Open &&
        stream.state != StreamState.HalfClosedRemote) {
      throw StateError('Idle state expected.');
    }

    stream.outgoingQueue
        .enqueueMessage(HeadersMessage(stream.id, headers, endStream));

    if (stream.state == StreamState.Idle) {
      _changeState(stream, StreamState.Open);
    }

    if (endStream) {
      _endStream(stream);
    }
  }

  void _sendData(Http2StreamImpl stream, List<int> data,
      {bool endStream = false}) {
    if (stream.state != StreamState.Open &&
        stream.state != StreamState.HalfClosedRemote) {
      throw StateError('Open state expected (was: ${stream.state}).');
    }

    stream.outgoingQueue
        .enqueueMessage(DataMessage(stream.id, data, endStream));

    if (endStream) {
      _endStream(stream);
    }
  }

  void _endStream(Http2StreamImpl stream) {
    if (stream.state == StreamState.Open) {
      _changeState(stream, StreamState.HalfClosedLocal);
    } else if (stream.state == StreamState.HalfClosedRemote) {
      _changeState(stream, StreamState.Closed);
    } else {
      throw StateError('Invalid state transition. This should never happen.');
    }
  }

  ////////////////////////////////////////////////////////////////////////////
  //// Stream closing
  ////////////////////////////////////////////////////////////////////////////

  void _cleanupClosedStream(Http2StreamImpl stream) {
    // NOTE: This function should only be called once
    //     * all incoming data has been delivered to the application
    //     * all outgoing data has been added to the connection queue.
    incomingQueue.removeStreamMessageQueue(stream.id);
    _openStreams.remove(stream.id);
    if (stream.state != StreamState.Terminated) {
      _changeState(stream, StreamState.Terminated);
    }
    if (_openStreams.isEmpty) {
      _onActiveStateChanged(false);
    }
    onCheckForClose();
  }

  void _closeStreamIdAbnormally(int streamId, Exception exception,
      {bool propagateException = false}) {
    var stream = _openStreams[streamId];
    if (stream != null) {
      _closeStreamAbnormally(stream, exception,
          propagateException: propagateException);
    }
  }

  void _closeStreamAbnormally(Http2StreamImpl stream, Object exception,
      {bool propagateException = false}) {
    incomingQueue.removeStreamMessageQueue(stream.id);

    if (stream.state != StreamState.Terminated) {
      _changeState(stream, StreamState.Terminated);
    }
    stream.incomingQueue.terminate(propagateException ? exception : null);
    stream._outgoingCSubscription.cancel();
    stream._outgoingC.close();

    // NOTE: we're not adding an error here.
    stream.outgoingQueue.terminate();

    onCheckForClose();
  }

  @override
  void onClosing() {
    _newStreamsC.close();
  }

  @override
  void onCheckForClose() {
    if (isClosing && _openStreams.isEmpty) {
      closeWithValue();
    }
  }

  ////////////////////////////////////////////////////////////////////////////
  //// State transitioning & Counting of active streams
  ////////////////////////////////////////////////////////////////////////////

  /// The number of streams which we initiated and which are in one of the open
  /// states (i.e. [StreamState.Open], [StreamState.HalfClosedLocal] or
  /// [StreamState.HalfClosedRemote])
  int _numberOfActiveStreams = 0;

  bool _canCreateNewStream() {
    var limit = _peerSettings.maxConcurrentStreams;
    return limit == null || _numberOfActiveStreams < limit;
  }

  bool _ranOutOfStreamIds() {
    return nextStreamId > MAX_STREAM_ID;
  }

  void _changeState(Http2StreamImpl stream, StreamState to) {
    var from = stream.state;

    // In checked mode we'll test that the state transition is allowed.
    assert((from == StreamState.Idle && to == StreamState.ReservedLocal) ||
        (from == StreamState.Idle && to == StreamState.ReservedRemote) ||
        (from == StreamState.Idle && to == StreamState.Open) ||
        (from == StreamState.Open && to == StreamState.HalfClosedLocal) ||
        (from == StreamState.Open && to == StreamState.HalfClosedRemote) ||
        (from == StreamState.Open && to == StreamState.Closed) ||
        (from == StreamState.HalfClosedLocal && to == StreamState.Closed) ||
        (from == StreamState.HalfClosedRemote && to == StreamState.Closed) ||
        (from == StreamState.ReservedLocal &&
            to == StreamState.HalfClosedRemote) ||
        (from == StreamState.ReservedLocal && to == StreamState.Closed) ||
        (from == StreamState.ReservedRemote && to == StreamState.Closed) ||
        (from == StreamState.ReservedRemote &&
            to == StreamState.HalfClosedLocal) ||
        (from != StreamState.Terminated && to == StreamState.Terminated));

    // If we initiated the stream and it became "open" or "closed" we need to
    // update the [_numberOfActiveStreams] counter.
    if (_didInitiateStream(stream)) {
      // NOTE: We wait until the stream is completely done.
      // (If we waited only until `StreamState.Closed` then we might still have
      //  the endStream header/data message buffered, but not yet sent out).
      switch (stream.state) {
        case StreamState.ReservedLocal:
        case StreamState.ReservedRemote:
        case StreamState.Idle:
          if (to == StreamState.Open ||
              to == StreamState.HalfClosedLocal ||
              to == StreamState.HalfClosedRemote) {
            _numberOfActiveStreams++;
          }
          break;
        case StreamState.Open:
        case StreamState.HalfClosedLocal:
        case StreamState.HalfClosedRemote:
        case StreamState.Closed:
          if (to == StreamState.Terminated) {
            _numberOfActiveStreams--;
          }
          break;
        case StreamState.Terminated:
          // There is nothing to do here.
          break;
      }
    }
    stream.state = to;
  }

  bool _didInitiateStream(Http2StreamImpl stream) {
    var id = stream.id;
    return (isServer && id.isEven) || (!isServer && id.isOdd);
  }
}
