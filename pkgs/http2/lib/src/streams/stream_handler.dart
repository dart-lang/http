// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.src.stream_handler;

import 'dart:async';

import '../../transport.dart';

import '../flowcontrol/connection_queues.dart';
import '../flowcontrol/stream_queues.dart';
import '../flowcontrol/queue_messages.dart';
import '../flowcontrol/window.dart';
import '../flowcontrol/window_handler.dart';
import '../frames/frames.dart';
import '../hpack/hpack.dart';
import '../settings/settings.dart';
import '../error_handler.dart';
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
                      implements ClientTransportStream,
                                 ServerTransportStream {
  /// The id of this stream.
  ///
  ///   * odd numbered streams are client streams
  ///   * even numbered streams are opened from the server
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

  final Function _pushStreamFun;

  StreamSubscription _outgoingCSubscription;

  Http2StreamImpl(this.incomingQueue,
                  this.outgoingQueue,
                  this._outgoingC,
                  this.id,
                  this.windowHandler,
                  this._pushStreamFun);

  /// A stream of data and/or headers from the remote end.
  Stream<StreamMessage> get incomingMessages => incomingQueue.messages;

  /// A sink for writing data and/or headers to the remote end.
  StreamSink<StreamMessage> get outgoingMessages => _outgoingC.sink;

  /// Streams which the server pushed to this endpoint.
  Stream<TransportStreamPush> get peerPushes => incomingQueue.serverPushes;

  /// Pushes a new stream to a client.
  ///
  /// The [requestHeaders] are the headers to which the pushed stream
  /// responds to.
  TransportStream push(List<Header> requestHeaders)
      => _pushStreamFun(this, requestHeaders);

  void terminate() {
    _outgoingCSubscription.cancel();
  }
}

/// Handles [Frame]s with a non-zero stream-id.
///
/// It keeps track of open streams, their state, their queues, forwards
/// messages from the connectionn level to stream level and vise versa.
// TODO: Respect SETTINGS_MAX_CONCURRENT_STREAMS
class StreamHandler extends Object with TerminatableMixin {
  static const int MAX_STREAM_ID = (1 << 31) - 1;
  final FrameWriter _frameWriter;
  final ConnectionMessageQueueIn incomingQueue;
  final ConnectionMessageQueueOut outgoingQueue;

  final StreamController<TransportStream> _newStreamsC = new StreamController();

  final Settings _peerSettings;
  final Settings _localSettings;

  final Map<int, Http2StreamImpl> _openStreams = {};
  int nextStreamId;
  int lastRemoteStreamId;

  bool get isServer => nextStreamId.isEven;

  StreamHandler._(this._frameWriter, this.incomingQueue, this.outgoingQueue,
                  this._peerSettings, this._localSettings,
                  this.nextStreamId, this.lastRemoteStreamId);

  factory StreamHandler.client(FrameWriter writer,
                               ConnectionMessageQueueIn incomingQueue,
                               ConnectionMessageQueueOut outgoingQueue,
                               Settings peerSettings, Settings localSettings) {
    return new StreamHandler._(
        writer, incomingQueue, outgoingQueue, peerSettings, localSettings,
        1, 0);
  }

  factory StreamHandler.server(FrameWriter writer,
                               ConnectionMessageQueueIn incomingQueue,
                               ConnectionMessageQueueOut outgoingQueue,
                               Settings peerSettings, Settings localSettings) {
    return new StreamHandler._(
        writer, incomingQueue, outgoingQueue, peerSettings, localSettings,
        2, -1);
  }

  void onTerminated(exception) {
    _openStreams.values.toList().forEach(
        (stream) => _closeStreamAbnormally(stream, exception));

    // Signal that there are no more incoming connections (server case).
    // FIXME: Should we do this always (even in client case?)
    _newStreamsC..addError(exception)..close();
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


  ////////////////////////////////////////////////////////////////////////////
  //// New local/remote Stream handling
  ////////////////////////////////////////////////////////////////////////////

  TransportStream newStream(List<Header> headers, {bool endStream: false}) {
    return ensureNotTerminatedSync(() {
      var stream = newLocalStream();
      _sendHeaders(stream, headers);
      if (endStream) {
        _handleOutgoingClose(stream);
      }
      return stream;
    });
  }

  TransportStream newLocalStream() {
    return ensureNotTerminatedSync(() {
      if (MAX_STREAM_ID < (nextStreamId + 2)) {
        throw new StateError(
            'Cannot create new streams, since a wrap around would happen.');
      }
      int streamId = nextStreamId;
      nextStreamId += 2;
      return _newStreamInternal(streamId);
    });
  }

  TransportStream newRemoteStream(int remoteStreamId) {
    return ensureNotTerminatedSync(() {
      assert (remoteStreamId < MAX_STREAM_ID);
      if (remoteStreamId != (lastRemoteStreamId + 2)) {
        // FIXME: Is this check ok? Can't there be holes in the streams?
        throw new StateError(
            'Remote end tries to create new stream which is not 2 higher than '
            'last one.');
      }
      bool sameDirection = (nextStreamId + remoteStreamId) % 2 == 0;
      assert (lastRemoteStreamId < remoteStreamId );
      assert (!sameDirection);

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

    var outgoingStreamWindow = new Window(
        initialSize: _peerSettings.initialWindowSize);

    var incomingStreamWindow = new Window(
        initialSize: _localSettings.initialWindowSize);

    var windowOutHandler = new OutgoingStreamWindowHandler(
        outgoingStreamWindow);

    var windowInHandler = new IncomingWindowHandler.stream(
        _frameWriter, incomingStreamWindow, streamId);

    var streamQueueIn = new StreamMessageQueueIn(windowInHandler);
    var streamQueueOut = new StreamMessageQueueOut(
        streamId, windowOutHandler, outgoingQueue);

    incomingQueue.insertNewStreamMessageQueue(streamId, streamQueueIn);

    var _outgoingC = new StreamController();
    var stream = new Http2StreamImpl(
        streamQueueIn, streamQueueOut, _outgoingC, streamId, windowOutHandler,
        this._push);
    _openStreams[stream.id] = stream;

    _setupOutgoingMessageHandling(stream);

    return stream;
  }

  TransportStream _push(Http2StreamImpl stream, List<Header> requestHeaders) {
    if (stream.state != StreamState.Open &&
        stream.state != StreamState.HalfClosedRemote) {
      throw new StateError('Cannot push based on a stream that is neither open '
                           'nor half-closed-remote.');
    }

    Http2StreamImpl pushStream = newLocalStream();

    // NOTE: Since there was no real request from the client, we simulate it
    // by adding a synthetic `endStream = true` Data message into the incoming
    // queue.
    pushStream.state = StreamState.HalfClosedRemote;
    pushStream.incomingQueue.enqueueMessage(
        new DataMessage(stream.id, const <int>[], true));

    _frameWriter.writePushPromiseFrame(
        stream.id, pushStream.id, requestHeaders);

    return pushStream;
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
            // TODO: We should really allow the endStream flag to be send with
            // the last headers/data frame. Should we add it to [StreamMessage]?
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
        var exception = new TransportException(
            'The first message on a stream needs to be a headers frame.');
        _closeStreamAbnormally(stream, exception);
        return;
      }
      stream.state = StreamState.Open;
    }

    if (msg is DataStreamMessage) {
      _sendData(stream, msg.bytes, endStream: false);
    } else if (msg is HeadersStreamMessage) {
      _sendHeaders(stream, msg.headers, endStream: false);
    }

    if (stream.outgoingQueue.bufferIndicator.wouldBuffer &&
        !stream._outgoingCSubscription.isPaused) {
      stream._outgoingCSubscription.pause();
    }
  }

  void _handleOutgoingClose(Http2StreamImpl stream) {
    // We allow multiple close calls.
    if (stream.state != StreamState.Closed) {
      _sendData(stream, const [], endStream: true);
    }
  }

  ////////////////////////////////////////////////////////////////////////////
  //// Process incoming stream frames
  ////////////////////////////////////////////////////////////////////////////

  void processStreamFrame(Frame frame) {
    // TODO: Consider splitting this method into client/server handling.
    return ensureNotTerminatedSync(() {
      var stream = _openStreams[frame.header.streamId];
      if (stream == null) {
        bool frameBelongsToIdleStream() {
          int streamId = frame.header.streamId;
          bool isServerStreamId = frame.header.streamId.isEven;
          bool isLocalStream = isServerStreamId == isServer;
          bool isIdleStream = isLocalStream ?
              streamId >= nextStreamId : streamId > lastRemoteStreamId;
          return isIdleStream;
        }

        if (frame is HeadersFrame) {
          if (isServer) {
            Http2StreamImpl newStream = newRemoteStream(frame.header.streamId);
            newStream.state = StreamState.Open;

            _handleHeadersFrame(newStream, frame);
            _newStreamsC.add(newStream);
          } else {
            // A server cannot open new streams to the client. The only way
            // for a server to start a new stream is via a PUSH_PROMISE_FRAME.
            throw new ProtocolException(
                'HTTP/2 clients cannot receive HEADER_FRAMEs as a connection'
                'attempt.');
          }
        } else if (frame is WindowUpdateFrame) {
          if (frameBelongsToIdleStream()) {
            // We treat this as a protocol error even though not enforced
            // or specified by the HTTP/2 spec.
            throw new ProtocolException(
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
            throw new ProtocolException(
                'Got a RST_STREAM_FRAME for an "idle" stream id.');
          } else {
            // [RstFrame]s for already dead (known as "closed") streams should
            // be ignored. (If the stream was in "HalfClosedRemote" and we did
            // send an endStream=true, it will be removed from the stream set).
          }
        } else {
          throw new StateError('No open stream found & was not headers frame.');
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
        } else {
          throw new StateError('Unsupported frame type ${frame.runtimeType}.');
        }
      }
    });
  }

  void _handleHeadersFrame(Http2StreamImpl stream, HeadersFrame frame) {
    if (stream.state == StreamState.ReservedRemote) {
      stream.state = StreamState.HalfClosedLocal;
    }

    if (stream.state != StreamState.Open &&
        stream.state != StreamState.HalfClosedLocal) {
      throw new StateError('Expected open state (was: ${stream.state}).');
    }

    incomingQueue.processHeadersFrame(frame);

    if (frame.hasEndStreamFlag) _handleEndOfStreamRemote(stream);
  }

  void _handleDataFrame(Http2StreamImpl stream, DataFrame frame) {
    if (stream.state != StreamState.Open &&
        stream.state != StreamState.HalfClosedLocal) {
      throw new StateError('Expected open state (was: ${stream.state}).');
    }

    incomingQueue.processDataFrame(frame);

    if (frame.hasEndStreamFlag) _handleEndOfStreamRemote(stream);
  }

  void _handlePushPromiseFrame(Http2StreamImpl stream, PushPromiseFrame frame) {
    if (stream.state != StreamState.Open &&
        stream.state != StreamState.HalfClosedLocal) {
      throw new StateError('Expected open state (was: ${stream.state}).');
    }

    var pushedStream = newRemoteStream(frame.promisedStreamId);
    pushedStream.state = StreamState.ReservedRemote;

    incomingQueue.processPushPromiseFrame(frame, pushedStream);
  }

  void _handleWindowUpdate(Http2StreamImpl stream, WindowUpdateFrame frame) {
    stream.windowHandler.processWindowUpdate(frame);
  }

  void _handleEndOfStreamRemote(Http2StreamImpl stream) {
    if (stream.state == StreamState.Open) {
      stream.state = StreamState.HalfClosedRemote;
    } else if (stream.state == StreamState.HalfClosedLocal) {
      stream.state = StreamState.Closed;
      // TODO: We have to make sure that we
      //   - remove the stream for data structures which only care about the
      //     state
      //   - keep the stream in data structures which need to be emptied
      //     (e.g. MessageQueues which are not empty yet).
      _openStreams.remove(stream.id);
    } else {
      throw new StateError(
          'Got an end-of-stream from the remote end, but this stream is '
          'neither in the Open nor in the HalfClosedLocal state.');
    }
  }


  ////////////////////////////////////////////////////////////////////////////
  //// Process outgoing stream messages
  ////////////////////////////////////////////////////////////////////////////

  void _sendHeaders(Http2StreamImpl stream, List<Header> headers,
                    {bool endStream: false}) {
    if (stream.state != StreamState.Idle &&
        stream.state != StreamState.Open &&
        stream.state != StreamState.HalfClosedRemote) {
      throw new StateError('Idle state expected.');
    }

    stream.outgoingQueue.enqueueMessage(
        new HeadersMessage(stream.id, headers, endStream));

    if (stream.state == StreamState.Idle) {
      stream.state = StreamState.Open;
    }

    if (endStream) {
      _endStream(stream);
    }
  }

  void _sendData(Http2StreamImpl stream, List<int> data,
                 {bool endStream: false}) {
    if (stream.state != StreamState.Open &&
        stream.state != StreamState.HalfClosedRemote) {
      throw new StateError('Open state expected (was: ${stream.state}).');
    }

    stream.outgoingQueue.enqueueMessage(
        new DataMessage(stream.id, data, endStream));

    if (endStream) {
      _endStream(stream);
    }
  }

  void _endStream(Http2StreamImpl stream) {
    if (stream.state == StreamState.Open) {
      stream.state = StreamState.HalfClosedLocal;
    } else if (stream.state == StreamState.HalfClosedRemote) {
      stream.state = StreamState.Closed;
    } else {
      throw new StateError('unknown state transition');
    }
    if (stream.state == StreamState.Closed) {
      _cleanupClosedStream(stream);
    }
  }

  ////////////////////////////////////////////////////////////////////////////
  //// Stream closing
  ////////////////////////////////////////////////////////////////////////////

  void _cleanupClosedStream(Http2StreamImpl stream) {
    incomingQueue.removeStreamMessageQueue(stream.id);
    _openStreams.remove(stream.id);
  }

  void _closeStreamAbnormally(Http2StreamImpl stream, Exception exception) {
    incomingQueue.removeStreamMessageQueue(stream.id);

    stream.state = StreamState.Terminated;
    stream.incomingQueue.terminate(exception);
    stream._outgoingCSubscription.cancel();

    // NOTE: we're not adding an error here.
    stream.outgoingQueue.terminate();
  }
}
