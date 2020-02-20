// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../error_handler.dart';
import '../frames/frames.dart';
import '../hpack/hpack.dart';
import '../sync_errors.dart';

/// The settings a remote peer can choose to set.
class ActiveSettings {
  /// Allows the sender to inform the remote endpoint of the maximum size of the
  /// header compression table used to decode header blocks, in octets. The
  /// encoder can select any size equal to or less than this value by using
  /// signaling specific to the header compression format inside a header block.
  /// The initial value is 4,096 octets.
  int headerTableSize;

  /// This setting can be use to disable server push (Section 8.2). An endpoint
  /// MUST NOT send a PUSH_PROMISE frame if it receives this parameter set to a
  /// value of 0. An endpoint that has both set this parameter to 0 and had it
  /// acknowledged MUST treat the receipt of a PUSH_PROMISE frame as a
  /// connection error (Section 5.4.1) of type PROTOCOL_ERROR.
  ///
  /// The initial value is 1, which indicates that server push is permitted.
  /// Any value other than 0 or 1 MUST be treated as a connection error
  /// (Section 5.4.1) of type PROTOCOL_ERROR.
  bool enablePush;

  /// Indicates the maximum number of concurrent streams that the sender will
  /// allow. This limit is directional: it applies to the number of streams that
  /// the sender permits the receiver to create. Initially there is no limit to
  /// this value. It is recommended that this value be no smaller than 100, so
  /// as to not unnecessarily limit parallelism.
  ///
  /// A value of 0 for SETTINGS_MAX_CONCURRENT_STREAMS SHOULD NOT be treated as
  /// special by endpoints. A zero value does prevent the creation of new
  /// streams, however this can also happen for any limit that is exhausted with
  /// active streams. Servers SHOULD only set a zero value for short durations;
  /// if a server does not wish to accept requests, closing the connection is
  /// more appropriate.
  int maxConcurrentStreams;

  /// Indicates the sender's initial window size (in octets) for stream level
  /// flow control. The initial value is 2^16-1 (65,535) octets.
  ///
  /// This setting affects the window size of all streams, including existing
  /// streams, see Section 6.9.2.
  /// Values above the maximum flow control window size of 231-1 MUST be treated
  /// as a connection error (Section 5.4.1) of type FLOW_CONTROL_ERROR.
  int initialWindowSize;

  /// Indicates the size of the largest frame payload that the sender is willing
  /// to receive, in octets.
  ///
  /// The initial value is 2^14 (16,384) octets. The value advertised by an
  /// endpoint MUST be between this initial value and the maximum allowed frame
  /// size (2^24-1 or 16,777,215 octets), inclusive. Values outside this range
  /// MUST be treated as a connection error (Section 5.4.1) of type
  /// PROTOCOL_ERROR.
  int maxFrameSize;

  /// This advisory setting informs a peer of the maximum size of header list
  /// that the sender is prepared to accept, in octets. The value is based on
  /// the uncompressed size of header fields, including the length of the name
  /// and value in octets plus an overhead of 32 octets for each header field.
  ///
  /// For any given request, a lower limit than what is advertised MAY be
  /// enforced. The initial value of this setting is unlimited.
  int maxHeaderListSize;

  ActiveSettings(
      {this.headerTableSize = 4096,
      this.enablePush = true,
      this.maxConcurrentStreams,
      this.initialWindowSize = (1 << 16) - 1,
      this.maxFrameSize = (1 << 14),
      this.maxHeaderListSize});
}

/// Handles remote and local connection [Setting]s.
///
/// Incoming [SettingsFrame]s will be handled here to update the peer settings.
/// Changes to [_toBeAcknowledgedSettings] can be made, the peer will then be
/// notified of the setting changes it should use.
class SettingsHandler extends Object with TerminatableMixin {
  /// Certain settings changes can change the maximum allowed dynamic table
  /// size used by the HPack encoder.
  final HPackEncoder _hpackEncoder;

  final FrameWriter _frameWriter;

  /// A list of outstanding setting changes.
  final List<List<Setting>> _toBeAcknowledgedSettings = [];

  /// A list of completers for outstanding setting changes.
  final List<Completer> _toBeAcknowledgedCompleters = [];

  /// The local settings, which the remote side ACKed to obey.
  final ActiveSettings _acknowledgedSettings;

  /// The peer settings, which we ACKed and are obeying.
  final ActiveSettings _peerSettings;

  final _onInitialWindowSizeChangeController =
      StreamController<int>.broadcast(sync: true);

  /// Events are fired when a SettingsFrame changes the initial size
  /// of stream windows.
  Stream<int> get onInitialWindowSizeChange =>
      _onInitialWindowSizeChangeController.stream;

  SettingsHandler(this._hpackEncoder, this._frameWriter,
      this._acknowledgedSettings, this._peerSettings);

  /// The settings for this endpoint of the connection which the remote peer
  /// has ACKed and uses.
  ActiveSettings get acknowledgedSettings => _acknowledgedSettings;

  /// The settings for the remote endpoint of the connection which this
  /// endpoint should use.
  ActiveSettings get peerSettings => _peerSettings;

  /// Handles an incoming [SettingsFrame] which can be an ACK or a settings
  /// change.
  void handleSettingsFrame(SettingsFrame frame) {
    ensureNotTerminatedSync(() {
      assert(frame.header.streamId == 0);

      if (frame.hasAckFlag) {
        assert(frame.header.length == 0);

        if (_toBeAcknowledgedSettings.isEmpty) {
          // NOTE: The specification does not say anything about ACKed settings
          // which were never sent to the other side. We consider this definitly
          // an error.
          throw ProtocolException(
              'Received an acknowledged settings frame which did not have a '
              'outstanding settings request.');
        }
        var settingChanges = _toBeAcknowledgedSettings.removeAt(0);
        var completer = _toBeAcknowledgedCompleters.removeAt(0);
        _modifySettings(_acknowledgedSettings, settingChanges, false);
        completer.complete();
      } else {
        _modifySettings(_peerSettings, frame.settings, true);
        _frameWriter.writeSettingsAckFrame();
      }
    });
  }

  @override
  void onTerminated(error) {
    _toBeAcknowledgedSettings.clear();
    _toBeAcknowledgedCompleters
        .forEach((Completer c) => c.completeError(error));
  }

  Future changeSettings(List<Setting> changes) {
    return ensureNotTerminatedAsync(() {
      // TODO: Have a timeout: When ACK doesn't get back in a reasonable time
      // frame we should quit with ErrorCode.SETTINGS_TIMEOUT.
      var completer = Completer();
      _toBeAcknowledgedSettings.add(changes);
      _toBeAcknowledgedCompleters.add(completer);
      _frameWriter.writeSettingsFrame(changes);
      return completer.future;
    });
  }

  void _modifySettings(
      ActiveSettings base, List<Setting> changes, bool peerSettings) {
    for (var setting in changes) {
      switch (setting.identifier) {
        case Setting.SETTINGS_ENABLE_PUSH:
          if (setting.value == 0) {
            base.enablePush = false;
          } else if (setting.value == 1) {
            base.enablePush = true;
          } else {
            throw ProtocolException(
                'The push setting can be only set to 0 or 1.');
          }
          break;

        case Setting.SETTINGS_HEADER_TABLE_SIZE:
          base.headerTableSize = setting.value;
          if (peerSettings) {
            _hpackEncoder.updateMaxSendingHeaderTableSize(base.headerTableSize);
          }
          break;

        case Setting.SETTINGS_MAX_HEADER_LIST_SIZE:
          // TODO: Propagate this signal to the HPackContext.
          base.maxHeaderListSize = setting.value;
          break;

        case Setting.SETTINGS_MAX_CONCURRENT_STREAMS:
          // NOTE: We will not force closing of existing streams if the limit is
          // lower than the current number of open streams. But we will prevent
          // new streams from being created if the number of existing streams
          // is above this limit.
          base.maxConcurrentStreams = setting.value;
          break;

        case Setting.SETTINGS_INITIAL_WINDOW_SIZE:
          if (setting.value < (1 << 31)) {
            var difference = setting.value - base.initialWindowSize;
            _onInitialWindowSizeChangeController.add(difference);
            base.initialWindowSize = setting.value;
          } else {
            throw FlowControlException('Invalid initial window size.');
          }
          break;

        default:
          // Spec says to ignore unknown settings.
          break;
      }
    }
  }
}
