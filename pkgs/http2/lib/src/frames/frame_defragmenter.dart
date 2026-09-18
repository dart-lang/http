// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import '../sync_errors.dart';
import 'frames.dart';

/// Defragments field blocks from [HeadersFrame]s and [PushPromiseFrame]s with
/// bounded buffering.
class FrameDefragmenter {
  final int? maxHeaderBlockSize;
  final int? maxContinuationFrames;

  Frame? _initialFrame;
  BytesBuilder? _fragments;
  int _fieldBlockSize = 0;
  int _combinedPayloadLength = 0;
  int _continuationFrames = 0;

  FrameDefragmenter({this.maxHeaderBlockSize, this.maxContinuationFrames}) {
    if (maxHeaderBlockSize case final limit? when limit < 0) {
      throw ArgumentError.value(limit, 'maxHeaderBlockSize', 'must be >= 0');
    }
    if (maxContinuationFrames case final limit? when limit < 0) {
      throw ArgumentError.value(limit, 'maxContinuationFrames', 'must be >= 0');
    }
  }

  /// Whether an incomplete field block is currently buffered.
  bool get isDefragmenting => _initialFrame != null;

  /// Tries to defragment [frame].
  ///
  /// Incomplete field blocks return `null`. A completed field block is returned
  /// as one [HeadersFrame] or [PushPromiseFrame]. Fragment bytes are retained
  /// as chunks and combined only once, avoiding repeated whole-block copies.
  Frame? tryDefragmentFrame(Frame? frame) {
    final initialFrame = _initialFrame;
    if (initialFrame != null) {
      if (frame is! ContinuationFrame) {
        _failProtocol(
          'Defragmentation: Incomplete frame must be followed by '
          'continuation frame.',
        );
      }
      if (initialFrame.header.streamId != frame.header.streamId) {
        _failProtocol('Defragmentation: frames have different stream ids.');
      }

      _continuationFrames++;
      final continuationLimit = maxContinuationFrames;
      if (continuationLimit != null &&
          _continuationFrames > continuationLimit) {
        _failResourceLimit(
          'Inbound field block used $_continuationFrames CONTINUATION frames, '
          'exceeding the limit of $continuationLimit.',
        );
      }

      _append(frame.headerBlockFragment);
      _combinedPayloadLength += frame.header.length;
      if (!frame.hasEndHeadersFlag) return null;

      final bytes = _fragments!.takeBytes();
      final combined = _complete(initialFrame, frame, bytes);
      _reset();
      return combined;
    }

    if (frame is HeadersFrame || frame is PushPromiseFrame) {
      final fragment = _headerBlockFragment(frame!);
      _checkHeaderBlockSize(fragment.length);
      if (!_hasEndHeadersFlag(frame)) {
        _initialFrame = frame;
        _fragments = BytesBuilder(copy: false)..add(fragment);
        _fieldBlockSize = fragment.length;
        _combinedPayloadLength = frame.header.length;
        return null;
      }
    }

    return frame;
  }

  void _append(List<int> fragment) {
    _checkHeaderBlockSize(_fieldBlockSize + fragment.length);
    _fragments!.add(fragment);
    _fieldBlockSize += fragment.length;
  }

  void _checkHeaderBlockSize(int size) {
    final limit = maxHeaderBlockSize;
    if (limit != null && size > limit) {
      _failResourceLimit(
        'Inbound compressed field block exceeds the limit '
        '($size bytes > $limit bytes).',
      );
    }
  }

  Frame _complete(
    Frame initialFrame,
    ContinuationFrame finalFrame,
    Uint8List bytes,
  ) {
    final header = FrameHeader(
      _combinedPayloadLength,
      initialFrame.header.type,
      initialFrame.header.flags | finalFrame.header.flags,
      initialFrame.header.streamId,
    );
    if (initialFrame is HeadersFrame) {
      return HeadersFrame(
        header,
        initialFrame.padLength,
        initialFrame.exclusiveDependency,
        initialFrame.streamDependency,
        initialFrame.weight,
        bytes,
      );
    }
    final pushPromise = initialFrame as PushPromiseFrame;
    return PushPromiseFrame(
      header,
      pushPromise.padLength,
      pushPromise.promisedStreamId,
      bytes,
    );
  }

  static List<int> _headerBlockFragment(Frame frame) => switch (frame) {
    HeadersFrame frame => frame.headerBlockFragment,
    PushPromiseFrame frame => frame.headerBlockFragment,
    _ => throw StateError('Expected HEADERS or PUSH_PROMISE frame.'),
  };

  static bool _hasEndHeadersFlag(Frame frame) => switch (frame) {
    HeadersFrame frame => frame.hasEndHeadersFlag,
    PushPromiseFrame frame => frame.hasEndHeadersFlag,
    _ => throw StateError('Expected HEADERS or PUSH_PROMISE frame.'),
  };

  Never _failProtocol(String message) {
    _reset();
    throw ProtocolException(message);
  }

  Never _failResourceLimit(String message) {
    _reset();
    throw HeaderBlockProcessingException(message);
  }

  void _reset() {
    _initialFrame = null;
    _fragments = null;
    _fieldBlockSize = 0;
    _combinedPayloadLength = 0;
    _continuationFrames = 0;
  }
}
