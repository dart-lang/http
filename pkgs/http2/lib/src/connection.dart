// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.src.conn;

import 'dart:async';
import 'dart:math';

import '../transport.dart';
import 'frames/frame_defragmenter.dart';
import 'frames/frames.dart';
import 'hpack/hpack.dart';
import 'ping/ping_handler.dart';
import 'settings/settings.dart';
import 'sync_errors.dart';

import 'connection_preface.dart';

enum ConnectionState {
  /// The connection has been established, we're waiting for the settings frame
  /// of the remote end.
  Initialized,

  /// The connection has been established and is fully operational.
  Operational,

  /// The connection is no longer accepting new streams or creating new streams.
  Finishing,

  /// The connection has been terminated and cannot be used anymore.
  Terminated,
}

class Connection implements TransportConnection {
  /// The settings the other end has acknowledged to use when communicating with
  /// us.
  final Settings acknowledgedSettings = new Settings();

  /// The settings we have to obey communicating with the other side.
  final Settings peerSettings = new Settings();

  /// Whether this connection is a client connection.
  final bool isClientConnection;

  /// The HPack context for this connection.
  final HPackContext _hpackContext = new HPackContext();

  /// Used for defragmenting PushPromise/Header frames.
  final FrameDefragmenter _defragmenter = new FrameDefragmenter();

  /// The outgoing frames of this connection;
  FrameWriter _frameWriter;

  /// A subscription of incoming [Frame]s.
  StreamSubscription<Frame> _frameReaderSubscription;

  /// The ping handler used for making pings & handling remote pings.
  PingHandler _pingHandler;

  /// The settings handler used for changing settings & for handling remote
  /// setting changes.
  SettingsHandler _settingsHandler;

  /// Represents the highest stream id this connection has received from the
  /// other side.
  int _highestStreamIdReceived = 0;

  /// The state of this connection.
  ConnectionState _state;

  factory Connection.client(Stream<List<int>> incoming,
                            StreamSink<List<int>> outgoing)  {
    outgoing.add(CONNECTION_PREFACE);
    return new Connection(incoming, outgoing, isClientConnection: true);
  }

  factory Connection.server(Stream<List<int>> incoming,
                            StreamSink<List<int>> outgoing) {
    var frameBytes = readConnectionPreface(incoming);
    return new Connection(frameBytes, outgoing, isClientConnection: false);
  }

  Connection(Stream<List<int>> incoming,
             StreamSink<List<int>> outgoing,
             {this.isClientConnection: true}) {
    _setupConnection(incoming, outgoing);
  }

  /// Runs all setup necessary before new streams can be created with the remote
  /// peer.
  void _setupConnection(Stream<List<int>> incoming,
                        StreamSink<List<int>> outgoing) {
    // Setup frame reading.
    var incomingFrames = new FrameReader(
        incoming, acknowledgedSettings).startDecoding();
    _frameReaderSubscription = incomingFrames.listen(
        _handleFrame,
        onError: (stack, error) {
          _terminate(ErrorCode.CONNECT_ERROR, causedByTransportError: true);
        }, onDone: () {
          _terminate(ErrorCode.CONNECT_ERROR, causedByTransportError: true);
        });

    // Setup frame writing.
    _frameWriter = new FrameWriter(
        _hpackContext.encoder, outgoing, peerSettings);
    _frameWriter.doneFuture.then((_) {
      _terminate(ErrorCode.CONNECT_ERROR, causedByTransportError: true);
    }).catchError((error, stack) {
      _terminate(ErrorCode.CONNECT_ERROR, causedByTransportError: true);
    });

    // Setup handlers.
    _settingsHandler = new SettingsHandler(
        _frameWriter, acknowledgedSettings, peerSettings);
    _pingHandler = new PingHandler(_frameWriter);

    // Do the initial settings handshake.
    _settingsHandler.changeSettings([]).catchError((_) {
      _terminate(ErrorCode.PROTOCOL_ERROR);
    });

    // NOTE: We're not waiting until initial settings have been exchanged
    // before we start using the connection (i.e. we don't wait for half a
    // round-trip-time).
    _state = ConnectionState.Initialized;
  }

  /// Pings the remote peer (can e.g. be used for measuring latency).
  Future ping() {
    return _pingHandler.ping().catchError((e, s) {
      return new Future.error(
          new TransportException('The connection has been terminated.'));
    }, test: (e) => e is TerminatedException);
  }

  /// Finishes this connection.
  void finish() {
    _finishing(active: true);
  }

  /// Terminates this connection forcefully.
  Future terminate() {
    return _terminate(ErrorCode.NO_ERROR);
  }

  /// Handles an incoming [Frame] from the underlying [FrameReader].
  void _handleFrame(Frame frame) {
    // The first frame from the other side must be a [SettingsFrame], otherwise
    // we terminate the connection.
    if (_state == ConnectionState.Initialized) {
      if (frame is! SettingsFrame) {
        _terminate(ErrorCode.PROTOCOL_ERROR);
        return;
      }
      _state = ConnectionState.Operational;
    }

    // Try to decode frame if it is a Headers/PushPromise frame.
    try {
      frame = _defragmenter.tryDefragmentFrame(frame);
      if (frame == null) return;
    } on ProtocolException {
      _terminate(ErrorCode.PROTOCOL_ERROR);
      return;
    }

    // Try to decode headers if it's a Headers/PushPromise frame.
    // [This needs to be done even if the frames get ignored, since the entire
    //  connection shares one HPack compression context.]
    try {
      if (frame is HeadersFrame) {
        frame.decodedHeaders =
            _hpackContext.decoder.decode(frame.headerBlockFragment);
      } else if (frame is PushPromiseFrame) {
        frame.decodedHeaders =
            _hpackContext.decoder.decode(frame.headerBlockFragment);
      }
    } on HPackDecodingException {
      _terminate(ErrorCode.PROTOCOL_ERROR);
    }

    // Update highest stream id we received.
    _highestStreamIdReceived =
        max(_highestStreamIdReceived, frame.header.streamId);

    // Handle the frame as either a stream or a connection frame.
    if (frame.header.streamId == 0) {
      if (frame is SettingsFrame) {
        _settingsHandler.handleSettingsFrame(frame);
      } else if (frame is PingFrame) {
        _pingHandler.processPingFrame(frame);
      } else if (frame is WindowUpdateFrame) {
        // TODO: Implement this.
        throw new UnimplementedError();
      } else if (frame is GoawayFrame) {
        // TODO: What to do about [frame.lastStreamIdReceived] ?
        _finishing(active: false);
      } else if (frame is UnknownFrame) {
        // We can safely ignore these.
      } else {
        throw 'Unknown incoming frame ${frame.runtimeType}';
      }
    } else {
      // We will not process frames for stream id's which are higher than when
      // we sent the [GoawayFrame].
      if (_state == ConnectionState.Finishing &&
          frame.header.streamId > highestSeenStreamId) {
        return;
      }

      // TODO: Hand frame over to StreamHandler.
    }
  }

  void _finishing({bool active: true}) {
    // If this connection is already finishing or dead, we return.
    if (_state == ConnectionState.Terminated ||
        _state == ConnectionState.Finishing) {
      return;
    }

    if (_state == ConnectionState.Initialized ||
        _state == ConnectionState.Operational) {
      _state = ConnectionState.Finishing;

      // If we are actively finishing this connection, we'll send a
      // GoawayFrame otherwise we'll just propagate the message.
      if (active) {
        _frameWriter.writeGoawayFrame(
            highestSeenStreamId, ErrorCode.NO_ERROR, []);
      }

      // TODO: Propagate to the [StreamSet] that we no longer process new
      // streams. And make it return a Future which we can listen to until
      // all streams are done.
    }
  }

  /// Terminates this connection (if it is not already terminated).
  ///
  /// The returned future will never complete with an error.
  Future _terminate(int errorCode, {bool causedByTransportError: false}) {
    // TODO: When do we complete here?
    if (_state != ConnectionState.Terminated) {
      _state = ConnectionState.Terminated;

      var cancelFuture = new Future.sync(_frameReaderSubscription.cancel);
      if (!causedByTransportError) {
        _frameWriter.writeGoawayFrame(highestSeenStreamId, errorCode, []);
      }
      var closeFuture = _frameWriter.close().catchError((e, s) {
        // We ignore any errors after writing to [GoawayFrame]
      });

      // Close all lower level handlers with an error message.
      // (e.g. if there is a pending connection.ping(), it's returned
      //  Future will complete with this error).
      var exception = new TransportConnectionException(
          errorCode, 'Connection is being forcefully terminated.');
      _pingHandler.terminate(exception);
      _settingsHandler.terminate(exception);

      return Future.wait([cancelFuture, closeFuture]).catchError((_) {});
    }
    return new Future.value();
  }

  /// The highest stream id which has been used anywhere.
  int get highestSeenStreamId =>
      max(_highestStreamIdReceived, _frameWriter.highestWrittenStreamId);
}
