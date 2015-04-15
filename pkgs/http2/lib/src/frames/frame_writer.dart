// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of http2.src.frames;

// TODO: Register for window update events.
// TODO: Register for setting update events.
// TODO: No support for writing padded information.
// TODO: No support for stream priorities.
class FrameWriter {
  /// The HPack compression context.
  final HPackEncoder _hpackEncoder;

  /// A buffered writer for outgoing bytes.
  final BufferedBytesWriter _outWriter;

  /// Connection settings which this writer needs to respect.
  final Settings _peerSettings;

  /// This is the maximum over all stream id's we've written to the underlying
  /// sink.
  int _highestWrittenStreamId = 0;

  /// Whether this [FrameWriter] is closed.
  bool _isClosed = false;

  FrameWriter(this._hpackEncoder,
              StreamSink<List<int>> outgoing,
              this._peerSettings)
      : _outWriter = new BufferedBytesWriter(outgoing);

  /// A indicator whether writes would be buffered.
  BufferIndicator get bufferIndicator => _outWriter.bufferIndicator;

  /// This is the maximum over all stream id's we've written to the underlying
  /// sink.
  int get highestWrittenStreamId => _highestWrittenStreamId;

  void writeDataFrame(int streamId, List<int> data, {bool endStream: false}) {
    while (data.length > _peerSettings.maxFrameSize) {
      var chunk = viewOrSublist(data, 0, _peerSettings.maxFrameSize);
      data = viewOrSublist(data, _peerSettings.maxFrameSize,
                            data.length - _peerSettings.maxFrameSize);
      _writeDataFrameNoFragment(streamId, chunk, false);
    }
    _writeDataFrameNoFragment(streamId, data, endStream);
  }

  void _writeDataFrameNoFragment(int streamId, List<int> data, bool endStream) {
    int type = FrameType.DATA;
    int flags = endStream ? DataFrame.FLAG_END_STREAM : 0;

    var buffer = new Uint8List(FRAME_HEADER_SIZE + data.length);
    int offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, data.length);
    offset += FRAME_HEADER_SIZE;

    buffer.setRange(offset, offset + data.length, data);

    _writeData(buffer);
  }

  void writeHeadersFrame(int streamId, List<Header> headers,
                         {bool endStream: true}) {
    var fragment = _hpackEncoder.encode(headers);
    var maxSize =
        _peerSettings.maxFrameSize - HeadersFrame.MAX_CONSTANT_PAYLOAD;

    if (fragment.length < maxSize) {
      _writeHeadersFrameNoFragment(streamId, fragment, true, endStream);
    } else {
      var chunk = fragment.sublist(0, maxSize);
      fragment = fragment.sublist(maxSize);
      _writeHeadersFrameNoFragment(streamId, chunk, false, endStream);
      while (fragment.length > _peerSettings.maxFrameSize) {
        var chunk = fragment.sublist(0, _peerSettings.maxFrameSize);
        fragment = fragment.sublist(_peerSettings.maxFrameSize);
        _writeContinuationFrame(streamId, chunk, false);
      }
      _writeContinuationFrame(streamId, fragment, true);
    }
  }

  void _writeHeadersFrameNoFragment(int streamId, List<int> fragment,
                                    bool endHeaders, bool endStream) {
    int type = FrameType.HEADERS;
    int flags = 0;
    if (endHeaders) flags |= HeadersFrame.FLAG_END_HEADERS;
    if (endStream) flags |= HeadersFrame.FLAG_END_STREAM;

    var buffer = new Uint8List(FRAME_HEADER_SIZE + fragment.length);
    int offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, fragment.length);
    offset += FRAME_HEADER_SIZE;

    buffer.setRange(offset, buffer.length, fragment);

    _writeData(buffer);
  }

  void _writeContinuationFrame(int streamId, List<int> fragment,
                               bool endHeaders) {
    int type = FrameType.CONTINUATION;
    int flags = endHeaders ? ContinuationFrame.FLAG_END_HEADERS : 0;

    var buffer = new Uint8List(FRAME_HEADER_SIZE + fragment.length);
    int offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, fragment.length);
    offset += FRAME_HEADER_SIZE;

    buffer.setRange(offset, buffer.length, fragment);

    _writeData(buffer);
  }

  void writePriorityFrame(int streamId, int streamDependency,
                          int weight, {bool exclusive: false}) {
    int type = FrameType.PRIORITY;
    int flags = 0;

    var buffer = new Uint8List(
        FRAME_HEADER_SIZE + PriorityFrame.FIXED_FRAME_LENGTH);
    int offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, 5);
    offset += FRAME_HEADER_SIZE;

    if (exclusive) {
      _setInt32(buffer, offset, (1 << 31) | streamDependency);
    } else {
      _setInt32(buffer, offset, streamDependency);
    }
    buffer[offset + 4] = weight;

    _writeData(buffer);
  }

  void writeRstStreamFrame(int streamId, int errorCode) {
    int type = FrameType.RST_STREAM;
    int flags = 0;

    var buffer = new Uint8List(
        FRAME_HEADER_SIZE + RstStreamFrame.FIXED_FRAME_LENGTH);
    int offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, 4);
    offset += FRAME_HEADER_SIZE;

    _setInt32(buffer, offset, errorCode);

    _writeData(buffer);
  }

  void writeSettingsFrame(List<Setting> settings) {
    int type = FrameType.SETTINGS;
    int flags = 0;

    var buffer = new Uint8List(FRAME_HEADER_SIZE + 6 * settings.length);
    int offset = 0;

    _setFrameHeader(buffer, offset, type, flags, 0, 6 * settings.length);
    offset += FRAME_HEADER_SIZE;

    for (int i = 0; i < settings.length; i++) {
      var setting = settings[i];
      _setInt16(buffer, offset + 6 * i, setting.identifier);
      _setInt32(buffer, offset + 6 * i + 2, setting.value);
    }

    _writeData(buffer);
  }

  void writeSettingsAckFrame() {
    int type = FrameType.SETTINGS;
    int flags = SettingsFrame.FLAG_ACK;

    var buffer = new Uint8List(FRAME_HEADER_SIZE);
    int offset = 0;

    _setFrameHeader(buffer, offset, type, flags, 0, 0);
    offset += FRAME_HEADER_SIZE;

    _writeData(buffer);
  }

  void writePushPromiseFrame(int streamId, int promisedStreamId,
                             List<Header> headers) {
    var fragment = _hpackEncoder.encode(headers);
    var maxSize =
        _peerSettings.maxFrameSize - PushPromiseFrame.MAX_CONSTANT_PAYLOAD;

    if (fragment.length < maxSize) {
      _writePushPromiseFrameNoFragmentation(
          streamId, promisedStreamId, fragment, true);
    } else {
      var chunk = fragment.sublist(0, maxSize);
      fragment = fragment.sublist(maxSize);
      _writePushPromiseFrameNoFragmentation(
          streamId, promisedStreamId, chunk,  false);
      while (fragment.length > _peerSettings.maxFrameSize) {
        var chunk = fragment.sublist(0, _peerSettings.maxFrameSize);
        fragment = fragment.sublist(_peerSettings.maxFrameSize);
        _writeContinuationFrame(streamId, chunk, false);
      }
      _writeContinuationFrame(streamId, chunk, true);
    }
  }

  void _writePushPromiseFrameNoFragmentation(
      int streamId, int promisedStreamId, List<int> fragment, bool endHeaders) {
    int type = FrameType.PUSH_PROMISE;
    int flags = endHeaders ? HeadersFrame.FLAG_END_HEADERS : 0;

    var buffer = new Uint8List(FRAME_HEADER_SIZE + 4 + fragment.length);
    int offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, 4 + fragment.length);
    offset += FRAME_HEADER_SIZE;

    _setInt32(buffer, offset, promisedStreamId);
    buffer.setRange(offset + 4, offset + 4 + fragment.length, fragment);

    _writeData(buffer);
  }

  void writePingFrame(int opaqueData, {bool ack: false}) {
    int type = FrameType.PING;
    int flags = ack ? PingFrame.FLAG_ACK : 0;

    var buffer = new Uint8List(
        FRAME_HEADER_SIZE + PingFrame.FIXED_FRAME_LENGTH);
    int offset = 0;

    _setFrameHeader(buffer, 0, type, flags, 0, 8);
    offset += FRAME_HEADER_SIZE;

    _setInt64(buffer, offset, opaqueData);
    _writeData(buffer);
  }

  void writeGoawayFrame(int lastStreamId, int errorCode, List<int> debugData) {
    int type = FrameType.GOAWAY;
    int flags = 0;

    var buffer = new Uint8List(FRAME_HEADER_SIZE + 8 + debugData.length);
    int offset = 0;

    _setFrameHeader(buffer, offset, type, flags, 0, 8 + debugData.length);
    offset += FRAME_HEADER_SIZE;

    _setInt32(buffer, offset, lastStreamId);
    _setInt32(buffer, offset + 4, errorCode);
    buffer.setRange(offset + 8, buffer.length, debugData);

    _writeData(buffer);
  }

  void writeWindowUpdate(int sizeIncrement, {int streamId: 0}) {
    int type = FrameType.WINDOW_UPDATE;
    int flags = 0;

    var buffer = new Uint8List(
        FRAME_HEADER_SIZE + WindowUpdateFrame.FIXED_FRAME_LENGTH);
    int offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, 4);
    offset += FRAME_HEADER_SIZE;

    _setInt32(buffer, offset, sizeIncrement);

    _writeData(buffer);
  }

  void _writeData(List<int> bytes) {
    if (_isClosed) {
      // We do ignore any frames after this [FrameWriter] has been closed.
      return;
    }

    _outWriter.add(bytes);
  }

  /// Closes the underlying sink and returns [doneFuture].
  Future close() {
    return _outWriter.close().whenComplete(() => doneFuture);
  }

  /// The future which will complete once this writer is done.
  Future get doneFuture => _outWriter.doneFuture;

  void _setFrameHeader(List<int> bytes, int offset,
                       int type, int flags, int streamId, int length) {
    _setInt24(bytes, offset, length);
    bytes[3] = type;
    bytes[4] = flags;
    _setInt32(bytes, 5, streamId);

    _highestWrittenStreamId = max(_highestWrittenStreamId, streamId);
  }
}
