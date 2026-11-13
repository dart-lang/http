// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../transport.dart';

class ProtocolException implements Exception {
  final String _message;

  ProtocolException(this._message);

  @override
  String toString() => 'ProtocolError: $_message';
}

class FlowControlException implements Exception {
  final String _message;

  FlowControlException(this._message);

  @override
  String toString() => 'FlowControlException: $_message';
}

class FrameSizeException implements Exception {
  final String _message;

  FrameSizeException(this._message);

  @override
  String toString() => 'FrameSizeException: $_message';
}

/// An inbound field block exceeded a local resource limit.
class HeaderBlockProcessingException implements Exception {
  final String _message;

  HeaderBlockProcessingException(this._message);

  @override
  String toString() => 'HeaderBlockProcessingException: $_message';
}

/// The peer is exhibiting a behavior that might be generating excessive load
/// (RFC 9113 section 7, `ENHANCE_YOUR_CALM`).
class EnhanceYourCalmException implements Exception {
  final String _message;

  EnhanceYourCalmException(this._message);

  @override
  String toString() => 'EnhanceYourCalmException: $_message';
}

class TerminatedException implements Exception {
  @override
  String toString() => 'TerminatedException: The object has been terminated.';
}

class StreamException extends StreamTransportException {
  final int streamId;
  final String _details;

  StreamException(this.streamId, String details)
    : _details = details,
      super(details);

  @override
  String toString() => 'StreamException(stream id: $streamId): $_details';
}

class StreamClosedException extends StreamException {
  StreamClosedException(super.streamId, [super.details = '']);

  @override
  String toString() => 'StreamClosedException(stream id: $streamId): $_details';
}

class StreamRefusedException extends StreamException {
  StreamRefusedException(super.streamId, [super.details = '']);

  @override
  String toString() =>
      'StreamRefusedException(stream id: $streamId): $_details';
}

class StreamProtocolException extends StreamException {
  StreamProtocolException(super.streamId, [super.details = '']);

  @override
  String toString() =>
      'StreamProtocolException(stream id: $streamId): $_details';
}

class StreamFlowControlException extends StreamException {
  StreamFlowControlException(super.streamId, [super.details = '']);

  @override
  String toString() =>
      'StreamFlowControlException(stream id: $streamId): $_details';
}
