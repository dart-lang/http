// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../sync_errors.dart';

import 'frames.dart';

/// Class used for defragmenting [HeadersFrame]s and [PushPromiseFrame]s.
// TODO: Somehow emit an error if too many continuation frames have been sent
// (since we're buffering all of them).
class FrameDefragmenter {
  /// The current incomplete [HeadersFrame] fragment.
  HeadersFrame _headersFrame;

  /// The current incomplete [PushPromiseFrame] fragment.
  PushPromiseFrame _pushPromiseFrame;

  /// Tries to defragment [frame].
  ///
  /// If the given [frame] is a [HeadersFrame] or a [PushPromiseFrame] which
  /// needs de-fragmentation, it will be saved and `null` will be returned.
  ///
  /// If there is currently an incomplete [HeadersFrame] or [PushPromiseFrame]
  /// saved, [frame] needs to be a [ContinuationFrame]. It will be added to the
  /// saved frame. In case the defragmentation is complete, the defragmented
  /// [HeadersFrame] or [PushPromiseFrame] will be returned.
  ///
  /// All other [Frame] types will be returned.
  // TODO: Consider handling continuation frames without preceding
  // headers/push-promise frame here instead of the call site?
  Frame tryDefragmentFrame(Frame frame) {
    if (_headersFrame != null) {
      if (frame is ContinuationFrame) {
        if (_headersFrame.header.streamId != frame.header.streamId) {
          throw ProtocolException(
              'Defragmentation: frames have different stream ids.');
        }
        _headersFrame = _headersFrame.addBlockContinuation(frame);

        if (frame.hasEndHeadersFlag) {
          var frame = _headersFrame;
          _headersFrame = null;
          return frame;
        } else {
          return null;
        }
      } else {
        throw ProtocolException(
            'Defragmentation: Incomplete frame must be followed by '
            'continuation frame.');
      }
    } else if (_pushPromiseFrame != null) {
      if (frame is ContinuationFrame) {
        if (_pushPromiseFrame.header.streamId != frame.header.streamId) {
          throw ProtocolException(
              'Defragmentation: frames have different stream ids.');
        }
        _pushPromiseFrame = _pushPromiseFrame.addBlockContinuation(frame);

        if (frame.hasEndHeadersFlag) {
          var frame = _pushPromiseFrame;
          _pushPromiseFrame = null;
          return frame;
        } else {
          return null;
        }
      } else {
        throw ProtocolException(
            'Defragmentation: Incomplete frame must be followed by '
            'continuation frame.');
      }
    } else {
      if (frame is HeadersFrame) {
        if (!frame.hasEndHeadersFlag) {
          _headersFrame = frame;
          return null;
        }
      } else if (frame is PushPromiseFrame) {
        if (!frame.hasEndHeadersFlag) {
          _pushPromiseFrame = frame;
          return null;
        }
      }
    }

    // If this frame is not relevant for header defragmentation, we pass it to
    // the next stage.
    return frame;
  }
}
