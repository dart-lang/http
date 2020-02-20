// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of http2.src.frames;

// TODO: No support for writing padded information.
// TODO: No support for stream priorities.
class FrameWriter {
  /// The HPack compression context.
  final HPackEncoder _hpackEncoder;

  /// A buffered writer for outgoing bytes.
  final BufferedBytesWriter _outWriter;

  /// Connection settings which this writer needs to respect.
  final ActiveSettings _peerSettings;

  /// This is the maximum over all stream id's we've written to the underlying
  /// sink.
  int _highestWrittenStreamId = 0;

  FrameWriter(
      this._hpackEncoder, StreamSink<List<int>> outgoing, this._peerSettings)
      : _outWriter = BufferedBytesWriter(outgoing);

  /// A indicator whether writes would be buffered.
  BufferIndicator get bufferIndicator => _outWriter.bufferIndicator;

  /// This is the maximum over all stream id's we've written to the underlying
  /// sink.
  int get highestWrittenStreamId => _highestWrittenStreamId;

  void writeDataFrame(int streamId, List<int> data, {bool endStream = false}) {
    while (data.length > _peerSettings.maxFrameSize) {
      var chunk = viewOrSublist(data, 0, _peerSettings.maxFrameSize);
      data = viewOrSublist(data, _peerSettings.maxFrameSize,
          data.length - _peerSettings.maxFrameSize);
      _writeDataFrameNoFragment(streamId, chunk, false);
    }
    _writeDataFrameNoFragment(streamId, data, endStream);
  }

  void _writeDataFrameNoFragment(int streamId, List<int> data, bool endStream) {
    var type = FrameType.DATA;
    var flags = endStream ? DataFrame.FLAG_END_STREAM : 0;

    var buffer = Uint8List(FRAME_HEADER_SIZE + data.length);
    var offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, data.length);
    offset += FRAME_HEADER_SIZE;

    buffer.setRange(offset, offset + data.length, data);

    _writeData(buffer);
  }

  void writeHeadersFrame(int streamId, List<Header> headers,
      {bool endStream = true}) {
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

  void _writeHeadersFrameNoFragment(
      int streamId, List<int> fragment, bool endHeaders, bool endStream) {
    var type = FrameType.HEADERS;
    var flags = 0;
    if (endHeaders) flags |= HeadersFrame.FLAG_END_HEADERS;
    if (endStream) flags |= HeadersFrame.FLAG_END_STREAM;

    var buffer = Uint8List(FRAME_HEADER_SIZE + fragment.length);
    var offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, fragment.length);
    offset += FRAME_HEADER_SIZE;

    buffer.setRange(offset, buffer.length, fragment);

    _writeData(buffer);
  }

  void _writeContinuationFrame(
      int streamId, List<int> fragment, bool endHeaders) {
    var type = FrameType.CONTINUATION;
    var flags = endHeaders ? ContinuationFrame.FLAG_END_HEADERS : 0;

    var buffer = Uint8List(FRAME_HEADER_SIZE + fragment.length);
    var offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, fragment.length);
    offset += FRAME_HEADER_SIZE;

    buffer.setRange(offset, buffer.length, fragment);

    _writeData(buffer);
  }

  void writePriorityFrame(int streamId, int streamDependency, int weight,
      {bool exclusive = false}) {
    var type = FrameType.PRIORITY;
    var flags = 0;

    var buffer =
        Uint8List(FRAME_HEADER_SIZE + PriorityFrame.FIXED_FRAME_LENGTH);
    var offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, 5);
    offset += FRAME_HEADER_SIZE;

    if (exclusive) {
      setInt32(buffer, offset, (1 << 31) | streamDependency);
    } else {
      setInt32(buffer, offset, streamDependency);
    }
    buffer[offset + 4] = weight;

    _writeData(buffer);
  }

  void writeRstStreamFrame(int streamId, int errorCode) {
    var type = FrameType.RST_STREAM;
    var flags = 0;

    var buffer =
        Uint8List(FRAME_HEADER_SIZE + RstStreamFrame.FIXED_FRAME_LENGTH);
    var offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, 4);
    offset += FRAME_HEADER_SIZE;

    setInt32(buffer, offset, errorCode);

    _writeData(buffer);
  }

  void writeSettingsFrame(List<Setting> settings) {
    var type = FrameType.SETTINGS;
    var flags = 0;

    var buffer = Uint8List(FRAME_HEADER_SIZE + 6 * settings.length);
    var offset = 0;

    _setFrameHeader(buffer, offset, type, flags, 0, 6 * settings.length);
    offset += FRAME_HEADER_SIZE;

    for (var i = 0; i < settings.length; i++) {
      var setting = settings[i];
      setInt16(buffer, offset + 6 * i, setting.identifier);
      setInt32(buffer, offset + 6 * i + 2, setting.value);
    }

    _writeData(buffer);
  }

  void writeSettingsAckFrame() {
    var type = FrameType.SETTINGS;
    var flags = SettingsFrame.FLAG_ACK;

    var buffer = Uint8List(FRAME_HEADER_SIZE);
    var offset = 0;

    _setFrameHeader(buffer, offset, type, flags, 0, 0);
    offset += FRAME_HEADER_SIZE;

    _writeData(buffer);
  }

  void writePushPromiseFrame(
      int streamId, int promisedStreamId, List<Header> headers) {
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
          streamId, promisedStreamId, chunk, false);
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
    var type = FrameType.PUSH_PROMISE;
    var flags = endHeaders ? HeadersFrame.FLAG_END_HEADERS : 0;

    var buffer = Uint8List(FRAME_HEADER_SIZE + 4 + fragment.length);
    var offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, 4 + fragment.length);
    offset += FRAME_HEADER_SIZE;

    setInt32(buffer, offset, promisedStreamId);
    buffer.setRange(offset + 4, offset + 4 + fragment.length, fragment);

    _writeData(buffer);
  }

  void writePingFrame(int opaqueData, {bool ack = false}) {
    var type = FrameType.PING;
    var flags = ack ? PingFrame.FLAG_ACK : 0;

    var buffer = Uint8List(FRAME_HEADER_SIZE + PingFrame.FIXED_FRAME_LENGTH);
    var offset = 0;

    _setFrameHeader(buffer, 0, type, flags, 0, 8);
    offset += FRAME_HEADER_SIZE;

    setInt64(buffer, offset, opaqueData);
    _writeData(buffer);
  }

  void writeGoawayFrame(int lastStreamId, int errorCode, List<int> debugData) {
    var type = FrameType.GOAWAY;
    var flags = 0;

    var buffer = Uint8List(FRAME_HEADER_SIZE + 8 + debugData.length);
    var offset = 0;

    _setFrameHeader(buffer, offset, type, flags, 0, 8 + debugData.length);
    offset += FRAME_HEADER_SIZE;

    setInt32(buffer, offset, lastStreamId);
    setInt32(buffer, offset + 4, errorCode);
    buffer.setRange(offset + 8, buffer.length, debugData);

    _writeData(buffer);
  }

  void writeWindowUpdate(int sizeIncrement, {int streamId = 0}) {
    var type = FrameType.WINDOW_UPDATE;
    var flags = 0;

    var buffer =
        Uint8List(FRAME_HEADER_SIZE + WindowUpdateFrame.FIXED_FRAME_LENGTH);
    var offset = 0;

    _setFrameHeader(buffer, offset, type, flags, streamId, 4);
    offset += FRAME_HEADER_SIZE;

    setInt32(buffer, offset, sizeIncrement);

    _writeData(buffer);
  }

  void _writeData(List<int> bytes) {
    _outWriter.add(bytes);
  }

  /// Closes the underlying sink and returns [doneFuture].
  Future close() {
    return _outWriter.close().whenComplete(() => doneFuture);
  }

  /// The future which will complete once this writer is done.
  Future get doneFuture => _outWriter.doneFuture;

  void _setFrameHeader(List<int> bytes, int offset, int type, int flags,
      int streamId, int length) {
    setInt24(bytes, offset, length);
    bytes[3] = type;
    bytes[4] = flags;
    setInt32(bytes, 5, streamId);

    _highestWrittenStreamId = max(_highestWrittenStreamId, streamId);
  }
}
