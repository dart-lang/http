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
          'window too large.');
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
  OutgoingConnectionWindowHandler(Window window) : super(window);
}

/// Handles the window for outgoing messages to the peer.
class OutgoingStreamWindowHandler extends AbstractOutgoingWindowHandler {
  OutgoingStreamWindowHandler(Window window) : super(window);

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
          'window too large.');
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

  IncomingWindowHandler.stream(
      this._frameWriter, this._localWindow, this._streamId);

  IncomingWindowHandler.connection(this._frameWriter, this._localWindow)
      : _streamId = 0;

  /// The current size for the incoming data window.
  ///
  /// (This should never get negative, otherwise the peer send us more data
  ///  than we told it to send.)
  int get localWindowSize => _localWindow.size;

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
          'Connection level flow control window became negative.');
    }
  }

  /// Tell the peer we received [numberOfBytes] bytes. It will increase it's
  /// sending window then.
  ///
  // TODO/FIXME: If we pause and don't want to get more data, we have to
  //  - either stop sending window update frames
  //  - or decreasing the window size
  void dataProcessed(int numberOfBytes) {
    _localWindow.modify(numberOfBytes);

    // TODO: This can be optimized by delaying the window update to
    // send one update with a bigger difference than multiple small update
    // frames.
    _frameWriter.writeWindowUpdate(numberOfBytes, streamId: _streamId);
  }
}
