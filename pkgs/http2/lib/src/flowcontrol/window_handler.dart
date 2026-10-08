// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../async_utils/async_utils.dart';
import '../frames/frames.dart';
import '../sync_errors.dart';

import 'window.dart';

abstract class AbstractOutgoingWindowHandler {
  /// The connection flow control window.
  final Window _peerWindow;

  /// Indicates when the outgoing connection window turned positive and we can
  /// send data frames again.
  final BufferIndicator positiveWindow = BufferIndicator();

  AbstractOutgoingWindowHandler(this._peerWindow) {
    if (_peerWindow.size > 0) {
      positiveWindow.markUnBuffered();
    }
  }

  /// The flow control window size we use for sending data. We are not allowed
  /// to let this window be negative.
  int get peerWindowSize => _peerWindow.size;

  /// Process a window update frame received from the remote end.
  void processWindowUpdate(WindowUpdateFrame frame) {
    var increment = frame.windowSizeIncrement;
    if ((_peerWindow.size + increment) > Window.MAX_WINDOW_SIZE) {
      throw FlowControlException(
        'Window update received from remote peer would make flow control '
        'window too large.',
      );
    } else {
      _peerWindow.modify(increment);
    }

    // If we transitioned from an negative/empty window to a positive window
    // we'll fire an event that more data frames can be sent now.
    if (positiveWindow.wouldBuffer && _peerWindow.size > 0) {
      positiveWindow.markUnBuffered();
    }
  }

  /// Update the peer window by subtracting [numberOfBytes].
  ///
  /// The remote peer will send us [WindowUpdateFrame]s which will increase
  /// the window again at a later point in time.
  void decreaseWindow(int numberOfBytes) {
    _peerWindow.modify(-numberOfBytes);
    if (_peerWindow.size <= 0) {
      positiveWindow.markBuffered();
    }
  }
}

/// Handles the connection window for outgoing data frames.
class OutgoingConnectionWindowHandler extends AbstractOutgoingWindowHandler {
  OutgoingConnectionWindowHandler(super.window);
}

/// Handles the window for outgoing messages to the peer.
class OutgoingStreamWindowHandler extends AbstractOutgoingWindowHandler {
  OutgoingStreamWindowHandler(super.window);

  /// Update the peer window by adding [difference] to it.
  ///
  ///
  /// The remote peer has send a new [SettingsFrame] which updated the default
  /// stream level [Setting.SETTINGS_INITIAL_WINDOW_SIZE]. This causes all
  /// existing streams to update the flow stream-level flow control window.
  void processInitialWindowSizeSettingChange(int difference) {
    if ((_peerWindow.size + difference) > Window.MAX_WINDOW_SIZE) {
      throw FlowControlException(
        'Window update received from remote peer would make flow control '
        'window too large.',
      );
    } else {
      _peerWindow.modify(difference);
      if (_peerWindow.size <= 0) {
        positiveWindow.markBuffered();
      } else if (positiveWindow.wouldBuffer) {
        positiveWindow.markUnBuffered();
      }
    }
  }
}

/// Mirrors the flow control window the remote end is using.
class IncomingWindowHandler {
  /// The [FrameWriter] used for writing [WindowUpdateFrame]s to the wire.
  final FrameWriter _frameWriter;

  /// The mirror of the [Window] the remote end sees.
  ///
  /// If [_localWindow ] turns negative, it means the remote peer sent us more
  /// data than we allowed it to send.
  final Window _localWindow;

  /// The stream id this window handler is for (is `0` for connection level).
  final int _streamId;

  /// How much this end has let the peer send in all: the initial window plus
  /// every [raise].
  int _granted;

  /// Bytes processed since this end last sent a WINDOW_UPDATE.
  int _unacknowledged = 0;

  /// The initial window of a connection and of a stream (RFC 9113 section
  /// 6.9.2).
  static const _defaultWindowSize = 65535;

  IncomingWindowHandler.stream(
    this._frameWriter,
    Window localWindow,
    this._streamId,
  ) : _localWindow = localWindow,
      _granted = localWindow.size;

  IncomingWindowHandler.connection(this._frameWriter, Window localWindow)
    : _localWindow = localWindow,
      _granted = localWindow.size,
      _streamId = 0;

  /// The current size for the incoming data window.
  ///
  /// (This should never get negative, otherwise the peer send us more data
  ///  than we told it to send.)
  int get localWindowSize => _localWindow.size;

  /// Grants the peer [increment] more bytes than the window allows now, with
  /// no data received (RFC 9113 section 6.9): how a receive window grows past
  /// its initial size.
  void raise(int increment) {
    _granted += increment;
    _localWindow.modify(increment);
    _frameWriter.writeWindowUpdate(increment, streamId: _streamId);
  }

  /// Signals that we received [numberOfBytes] from the remote peer.
  void gotData(int numberOfBytes) {
    _localWindow.modify(-numberOfBytes);

    // If this turns negative, it means the remote end send us more data
    // then we announced we can handle (i.e. the remote window size must be
    // negative).
    //
    // NOTE: [_localWindow.size] tracks the amount of data we advertised that we
    // can handle. The value can change in three situations:
    //
    //    a) We received data from the remote end (we can handle now less data)
    //         => This is handled by [gotData].
    //
    //    b) We processed data from the remote end (we can handle now more data)
    //         => This is handled by [dataProcessed].
    //
    //    c) We increase/decrease the initial stream window size after the
    //       stream was created (newer streams will start with the changed
    //       initial stream window size).
    //         => This is not an issue, because we don't support changing the
    //            initial window size later on -- only during the initial
    //            settings exchange. Since streams (and therefore instances
    //            of [IncomingWindowHandler]) are only created after sending out
    //            our initial settings.
    //
    if (_localWindow.size < 0) {
      throw FlowControlException(
        'Connection level flow control window became negative.',
      );
    }
  }

  /// Tell the peer we received [numberOfBytes] bytes. It will increase it's
  /// sending window then.
  ///
  // TODO/FIXME: If we pause and don't want to get more data, we have to
  //  - either stop sending window update frames
  //  - or decreasing the window size
  void dataProcessed(int numberOfBytes) {
    // From twice the protocol's default 65535 bytes, one WINDOW_UPDATE per
    // half window processed rather than one per DATA frame: frame-by-frame
    // updates double the frames on the wire (the connection and the stream
    // each send one), and the peer keeps at least a default window in flight
    // while an update is held back. Below that a window is acknowledged at
    // once, as before: holding back half of it would leave the peer less than
    // the default.
    // An empty DATA frame frees nothing, and a WINDOW_UPDATE of 0 is a
    // PROTOCOL_ERROR (RFC 9113 section 6.9).
    if (numberOfBytes == 0) return;
    _unacknowledged += numberOfBytes;
    if (_granted >= 2 * _defaultWindowSize && _unacknowledged < _granted ~/ 2) {
      return;
    }
    _localWindow.modify(_unacknowledged);
    _frameWriter.writeWindowUpdate(_unacknowledged, streamId: _streamId);
    _unacknowledged = 0;
  }
}
