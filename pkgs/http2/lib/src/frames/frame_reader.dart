// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of http2.src.frames;

/// Used for converting a `Stream<List<int>>` to a `Stream<Frame>`.
class FrameReader {
  final Stream<List<int>> _inputStream;

  /// Connection settings which this reader needs to ensure the remote end is
  /// complying with.
  final ActiveSettings _localSettings;

  StreamSubscription<List<int>> _subscription;
  StreamController<Frame> _framesController;

  FrameReader(this._inputStream, this._localSettings);

  /// Starts to listen on the input stream and decodes HTTP/2 transport frames.
  Stream<Frame> startDecoding() {
    var bufferedData = <List<int>>[];
    var bufferedLength = 0;

    FrameHeader tryReadHeader() {
      if (bufferedLength >= FRAME_HEADER_SIZE) {
        // Get at least FRAME_HEADER_SIZE bytes in the first byte array.
        _mergeLists(bufferedData, FRAME_HEADER_SIZE);

        // Read the frame header from the first byte array.
        return _readFrameHeader(bufferedData[0], 0);
      }
      return null;
    }

    Frame tryReadFrame(FrameHeader header) {
      var totalFrameLen = FRAME_HEADER_SIZE + header.length;
      if (bufferedLength >= totalFrameLen) {
        // Get the whole frame in the first byte array.
        _mergeLists(bufferedData, totalFrameLen);

        // Read the frame.
        var frame = _readFrame(header, bufferedData[0], FRAME_HEADER_SIZE);

        // Update bufferedData/bufferedLength
        var firstChunkLen = bufferedData[0].length;
        if (firstChunkLen == totalFrameLen) {
          bufferedData.removeAt(0);
        } else {
          bufferedData[0] = viewOrSublist(
              bufferedData[0], totalFrameLen, firstChunkLen - totalFrameLen);
        }
        bufferedLength -= totalFrameLen;

        return frame;
      }
      return null;
    }

    _framesController = StreamController(
        onListen: () {
          FrameHeader header;

          void terminateWithError(error, [StackTrace stack]) {
            header = null;
            _framesController.addError(error, stack);
            _subscription.cancel();
            _framesController.close();
          }

          _subscription = _inputStream.listen((List<int> data) {
            bufferedData.add(data);
            bufferedLength += data.length;

            try {
              while (true) {
                header ??= tryReadHeader();
                if (header != null) {
                  if (header.length > _localSettings.maxFrameSize) {
                    terminateWithError(
                        FrameSizeException('Incoming frame is too big.'));
                    return;
                  }

                  var frame = tryReadFrame(header);

                  if (frame != null) {
                    _framesController.add(frame);
                    header = null;
                  } else {
                    break;
                  }
                } else {
                  break;
                }
              }
            } catch (error, stack) {
              terminateWithError(error, stack);
            }
          }, onError: (error, StackTrace stack) {
            terminateWithError(error, stack);
          }, onDone: () {
            if (bufferedLength == 0) {
              _framesController.close();
            } else {
              terminateWithError(FrameSizeException(
                  'Incoming byte stream ended with incomplete frame'));
            }
          });
        },
        onPause: () => _subscription.pause(),
        onResume: () => _subscription.resume());

    return _framesController.stream;
  }

  /// Combine combines/merges `List<int>`s of `bufferedData` until
  /// `numberOfBytes` have been accumulated.
  ///
  /// After calling `mergeLists`, `bufferedData[0]` will contain at least
  /// `numberOfBytes` bytes.
  void _mergeLists(List<List<int>> bufferedData, int numberOfBytes) {
    if (bufferedData[0].length < numberOfBytes) {
      var numLists = 0;
      var accumulatedLength = 0;
      while (accumulatedLength < numberOfBytes &&
          numLists <= bufferedData.length) {
        accumulatedLength += bufferedData[numLists++].length;
      }
      assert(accumulatedLength >= numberOfBytes);
      var newList = Uint8List(accumulatedLength);
      var offset = 0;
      for (var i = 0; i < numLists; i++) {
        var data = bufferedData[i];
        newList.setRange(offset, offset + data.length, data);
        offset += data.length;
      }
      bufferedData[0] = newList;
      bufferedData.removeRange(1, numLists);
    }
  }

  /// Reads a FrameHeader] from [bytes], starting at [offset].
  FrameHeader _readFrameHeader(List<int> bytes, int offset) {
    var length = readInt24(bytes, offset);
    var type = bytes[offset + 3];
    var flags = bytes[offset + 4];
    var streamId = readInt32(bytes, offset + 5) & 0x7fffffff;

    return FrameHeader(length, type, flags, streamId);
  }

  /// Reads a [Frame] from [bytes], starting at [frameOffset].
  Frame _readFrame(FrameHeader header, List<int> bytes, int frameOffset) {
    var frameEnd = frameOffset + header.length;

    var offset = frameOffset;
    switch (header.type) {
      case FrameType.DATA:
        var padLength = 0;
        if (_isFlagSet(header.flags, DataFrame.FLAG_PADDED)) {
          _checkFrameLengthCondition((frameEnd - offset) >= 1);
          padLength = bytes[offset++];
        }
        var dataLen = frameEnd - offset - padLength;
        _checkFrameLengthCondition(dataLen >= 0);
        var dataBytes = viewOrSublist(bytes, offset, dataLen);
        return DataFrame(header, padLength, dataBytes);

      case FrameType.HEADERS:
        var padLength = 0;
        if (_isFlagSet(header.flags, HeadersFrame.FLAG_PADDED)) {
          _checkFrameLengthCondition((frameEnd - offset) >= 1);
          padLength = bytes[offset++];
        }
        int streamDependency;
        var exclusiveDependency = false;
        int weight;
        if (_isFlagSet(header.flags, HeadersFrame.FLAG_PRIORITY)) {
          _checkFrameLengthCondition((frameEnd - offset) >= 5);
          exclusiveDependency = (bytes[offset] & 0x80) == 0x80;
          streamDependency = readInt32(bytes, offset) & 0x7fffffff;
          offset += 4;
          weight = bytes[offset++];
        }
        var headerBlockLen = frameEnd - offset - padLength;
        _checkFrameLengthCondition(headerBlockLen >= 0);
        var headerBlockFragment = viewOrSublist(bytes, offset, headerBlockLen);
        return HeadersFrame(header, padLength, exclusiveDependency,
            streamDependency, weight, headerBlockFragment);

      case FrameType.PRIORITY:
        _checkFrameLengthCondition(
            (frameEnd - offset) == PriorityFrame.FIXED_FRAME_LENGTH,
            message: 'Priority frame length must be exactly 5 bytes.');
        var exclusiveDependency = (bytes[offset] & 0x80) == 0x80;
        var streamDependency = readInt32(bytes, offset) & 0x7fffffff;
        var weight = bytes[offset + 4];
        return PriorityFrame(
            header, exclusiveDependency, streamDependency, weight);

      case FrameType.RST_STREAM:
        _checkFrameLengthCondition(
            (frameEnd - offset) == RstStreamFrame.FIXED_FRAME_LENGTH,
            message: 'Rst frames must have a length of 4.');
        var errorCode = readInt32(bytes, offset);
        return RstStreamFrame(header, errorCode);

      case FrameType.SETTINGS:
        _checkFrameLengthCondition((header.length % 6) == 0,
            message: 'Settings frame length must be a multiple of 6 bytes.');

        var count = header.length ~/ 6;
        var settings = List<Setting>(count);
        for (var i = 0; i < count; i++) {
          var identifier = readInt16(bytes, offset + 6 * i);
          var value = readInt32(bytes, offset + 6 * i + 2);
          settings[i] = Setting(identifier, value);
        }
        var frame = SettingsFrame(header, settings);
        if (frame.hasAckFlag) {
          _checkFrameLengthCondition(header.length == 0,
              message: 'Settings frame length must 0 for ACKs.');
        }
        return frame;

      case FrameType.PUSH_PROMISE:
        var padLength = 0;
        if (_isFlagSet(header.flags, PushPromiseFrame.FLAG_PADDED)) {
          _checkFrameLengthCondition((frameEnd - offset) >= 1);
          padLength = bytes[offset++];
        }
        var promisedStreamId = readInt32(bytes, offset) & 0x7fffffff;
        offset += 4;
        var headerBlockLen = frameEnd - offset - padLength;
        _checkFrameLengthCondition(headerBlockLen >= 0);
        var headerBlockFragment = viewOrSublist(bytes, offset, headerBlockLen);
        return PushPromiseFrame(
            header, padLength, promisedStreamId, headerBlockFragment);

      case FrameType.PING:
        _checkFrameLengthCondition(
            (frameEnd - offset) == PingFrame.FIXED_FRAME_LENGTH,
            message: 'Ping frames must have a length of 8.');
        var opaqueData = readInt64(bytes, offset);
        return PingFrame(header, opaqueData);

      case FrameType.GOAWAY:
        _checkFrameLengthCondition((frameEnd - offset) >= 8);
        var lastStreamId = readInt32(bytes, offset);
        var errorCode = readInt32(bytes, offset + 4);
        var debugData = viewOrSublist(bytes, offset + 8, header.length - 8);
        return GoawayFrame(header, lastStreamId, errorCode, debugData);

      case FrameType.WINDOW_UPDATE:
        _checkFrameLengthCondition(
            (frameEnd - offset) == WindowUpdateFrame.FIXED_FRAME_LENGTH,
            message: 'Window update frames must have a length of 4.');
        var windowSizeIncrement = readInt32(bytes, offset) & 0x7fffffff;
        return WindowUpdateFrame(header, windowSizeIncrement);

      case FrameType.CONTINUATION:
        var headerBlockFragment =
            viewOrSublist(bytes, offset, frameEnd - offset);
        return ContinuationFrame(header, headerBlockFragment);

      default:
        // Unknown frames should be ignored according to spec.
        return UnknownFrame(
            header, viewOrSublist(bytes, offset, frameEnd - offset));
    }
  }

  /// Checks that [condition] is `true` and raises an [FrameSizeException]
  /// otherwise.
  void _checkFrameLengthCondition(bool condition,
      {String message = 'Frame not long enough.'}) {
    if (!condition) {
      throw FrameSizeException(message);
    }
  }
}
