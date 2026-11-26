// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../error_handler.dart';
import '../frames/frames.dart';
import '../sync_errors.dart';

/// Responsible for pinging the other end and for handling pings from the
/// other end.
///
/// The peer's pings are acknowledged right away. [FrameWriter.writePingFrame]
/// throws if the peer does not read the acknowledgements, see
/// [FrameWriter.maxQueuedReplyFrames].
class PingHandler extends Object with TerminatableMixin {
  final FrameWriter _frameWriter;
  final Map<int, Completer> _remainingPings = {};
  final Sink<int>? pingReceived;
  final bool Function() isListeningToPings;
  int _nextId = 1;

  PingHandler(this._frameWriter, StreamController<int> pingStream)
    : pingReceived = pingStream.sink,
      isListeningToPings = (() => pingStream.hasListener);

  @override
  void onTerminated(Object? error) {
    final remainingPings = _remainingPings.values.toList();
    _remainingPings.clear();
    for (final ping in remainingPings) {
      ping.completeError(
        error ?? 'Remaining ping completed with unspecified error',
      );
    }
  }

  /// Processes an incoming [PingFrame].
  ///
  /// Returns `false` if [frame] has [PingFrame.FLAG_ACK] set for opaque data
  /// that does not match any outstanding local [ping], and `true` otherwise.
  bool processPingFrame(PingFrame frame) {
    return ensureNotTerminatedSync(() {
      if (frame.header.streamId != 0) {
        throw ProtocolException('Ping frames must have a stream id of 0.');
      }

      if (!frame.hasAckFlag) {
        if (isListeningToPings()) {
          pingReceived?.add(frame.opaqueData);
        }
        _frameWriter.writePingFrame(frame.opaqueData, ack: true);
        return true;
      } else {
        var c = _remainingPings.remove(frame.opaqueData);
        if (c != null) {
          c.complete();
          return true;
        }
        // RFC 9113 section 6.7: "An endpoint MUST NOT respond to PING frames
        // containing this flag." Ignore unsolicited PING(ACK) frames rather
        // than replying or tearing down the connection; the caller rate-limits
        // them against control/empty frame floods.
        return false;
      }
    });
  }

  Future ping() {
    return ensureNotTerminatedAsync(() {
      var c = Completer<void>();
      var id = _nextId++;
      _remainingPings[id] = c;
      _frameWriter.writePingFrame(id);
      return c.future;
    });
  }
}
