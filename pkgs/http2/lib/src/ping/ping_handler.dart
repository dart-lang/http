// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import '../error_handler.dart';
import '../frames/frames.dart';
import '../sync_errors.dart';

/// Responsible for pinging the other end and for handling pings from the
/// other end.
// TODO: We currently write unconditionally to the [FrameWriter]: we might want
// to consider be more aware what [Framewriter.bufferIndicator.wouldBuffer]
// says.
class PingHandler extends Object with TerminatableMixin {
  final FrameWriter _frameWriter;
  final Map<int, Completer> _remainingPings = {};
  int _nextId = 1;

  PingHandler(this._frameWriter);

  @override
  void onTerminated(error) {
    var values = _remainingPings.values.toList();
    _remainingPings.clear();
    values.forEach((Completer c) => c.completeError(error));
  }

  void processPingFrame(PingFrame frame) {
    ensureNotTerminatedSync(() {
      if (frame.header.streamId != 0) {
        throw ProtocolException('Ping frames must have a stream id of 0.');
      }

      if (!frame.hasAckFlag) {
        _frameWriter.writePingFrame(frame.opaqueData, ack: true);
      } else {
        var c = _remainingPings.remove(frame.opaqueData);
        if (c != null) {
          c.complete();
        } else {
          // NOTE: It is not specified what happens when one gets an ACK for a
          // ping we never sent. We be very strict and fail in this case.
          throw ProtocolException(
              'Received ping ack with unknown opaque data.');
        }
      }
    });
  }

  Future ping() {
    return ensureNotTerminatedAsync(() {
      var c = Completer();
      var id = _nextId++;
      _remainingPings[id] = c;
      _frameWriter.writePingFrame(id);
      return c.future;
    });
  }
}
