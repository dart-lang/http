// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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

class TerminatedException implements Exception {
  @override
  String toString() => 'TerminatedException: The object has been terminated.';
}

class StreamException implements Exception {
  final String _message;
  final int streamId;

  StreamException(this.streamId, this._message);

  @override
  String toString() => 'StreamException(stream id: $streamId): $_message';
}

class StreamClosedException extends StreamException {
  StreamClosedException(int streamId, [String message = ''])
      : super(streamId, message);

  @override
  String toString() => 'StreamClosedException(stream id: $streamId): $_message';
}
