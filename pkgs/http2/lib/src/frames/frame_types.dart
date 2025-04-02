// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'frames.dart';

const int FRAME_HEADER_SIZE = 9;

class FrameType {
  static const int DATA = 0;
  static const int HEADERS = 1;
  static const int PRIORITY = 2;
  static const int RST_STREAM = 3;
  static const int SETTINGS = 4;
  static const int PUSH_PROMISE = 5;
  static const int PING = 6;
  static const int GOAWAY = 7;
  static const int WINDOW_UPDATE = 8;
  static const int CONTINUATION = 9;
}

class ErrorCode {
  static const int NO_ERROR = 0;
  static const int PROTOCOL_ERROR = 1;
  static const int INTERNAL_ERROR = 2;
  static const int FLOW_CONTROL_ERROR = 3;
  static const int SETTINGS_TIMEOUT = 4;
  static const int STREAM_CLOSED = 5;
  static const int FRAME_SIZE_ERROR = 6;
  static const int REFUSED_STREAM = 7;
  static const int CANCEL = 8;
  static const int COMPRESSION_ERROR = 9;
  static const int CONNECT_ERROR = 10;
  static const int ENHANCE_YOUR_CALM = 11;
  static const int INADEQUATE_SECURITY = 12;
  static const int HTTP_1_1_REQUIRED = 13;
}

class FrameHeader {
  final int length;
  final int type;
  final int flags;
  final int streamId;

  FrameHeader(this.length, this.type, this.flags, this.streamId);

  Map toJson() => {
    'length': length,
    'type': type,
    'flags': flags,
    'streamId': streamId,
  };
}

class Frame {
  static const int MAX_LEN = (1 << 24) - 1;

  final FrameHeader header;

  Frame(this.header);

  Map toJson() => {'header': header.toJson()};
}

class DataFrame extends Frame {
  static const int FLAG_END_STREAM = 0x1;
  static const int FLAG_PADDED = 0x8;

  /// The number of padding bytes.
  final int padLength;

  final List<int> bytes;

  DataFrame(super.header, this.padLength, this.bytes);

  bool get hasEndStreamFlag => _isFlagSet(header.flags, FLAG_END_STREAM);
  bool get hasPaddedFlag => _isFlagSet(header.flags, FLAG_PADDED);

  @override
  Map toJson() =>
      super.toJson()..addAll({
        'padLength': padLength,
        'bytes (length)': bytes.length,
        'bytes (up to 4 bytes)': bytes.length > 4 ? bytes.sublist(0, 4) : bytes,
      });
}

class HeadersFrame extends Frame {
  static const int FLAG_END_STREAM = 0x1;
  static const int FLAG_END_HEADERS = 0x4;
  static const int FLAG_PADDED = 0x8;
  static const int FLAG_PRIORITY = 0x20;

  // NOTE: This is the size a [HeadersFrame] can have in addition to padding
  // and header block fragment data.
  static const int MAX_CONSTANT_PAYLOAD = 6;

  /// The number of padding bytes (might be null).
  final int padLength;

  final bool exclusiveDependency;
  final int? streamDependency;
  final int? weight;
  final List<int> headerBlockFragment;

  HeadersFrame(
    super.header,
    this.padLength,
    this.exclusiveDependency,
    this.streamDependency,
    this.weight,
    this.headerBlockFragment,
  );

  /// This will be set from the outside after decoding.
  late List<Header> decodedHeaders;

  bool get hasEndStreamFlag => _isFlagSet(header.flags, FLAG_END_STREAM);
  bool get hasEndHeadersFlag => _isFlagSet(header.flags, FLAG_END_HEADERS);
  bool get hasPaddedFlag => _isFlagSet(header.flags, FLAG_PADDED);
  bool get hasPriorityFlag => _isFlagSet(header.flags, FLAG_PRIORITY);

  HeadersFrame addBlockContinuation(ContinuationFrame frame) {
    var fragment = frame.headerBlockFragment;
    var flags = header.flags | frame.header.flags;
    var fh = FrameHeader(
      header.length + fragment.length,
      header.type,
      flags,
      header.streamId,
    );

    var mergedHeaderBlockFragment = Uint8List(
      headerBlockFragment.length + fragment.length,
    );

    mergedHeaderBlockFragment.setRange(
      0,
      headerBlockFragment.length,
      headerBlockFragment,
    );

    mergedHeaderBlockFragment.setRange(
      headerBlockFragment.length,
      mergedHeaderBlockFragment.length,
      fragment,
    );

    return HeadersFrame(
      fh,
      padLength,
      exclusiveDependency,
      streamDependency,
      weight,
      mergedHeaderBlockFragment,
    );
  }

  @override
  Map toJson() =>
      super.toJson()..addAll({
        'padLength': padLength,
        'exclusiveDependency': exclusiveDependency,
        'streamDependency': streamDependency,
        'weight': weight,
        'headerBlockFragment (length)': headerBlockFragment.length,
      });
}

class PriorityFrame extends Frame {
  static const int FIXED_FRAME_LENGTH = 5;

  final bool exclusiveDependency;
  final int streamDependency;
  final int weight;

  PriorityFrame(
    super.header,
    this.exclusiveDependency,
    this.streamDependency,
    this.weight,
  );

  @override
  Map toJson() =>
      super.toJson()..addAll({
        'exclusiveDependency': exclusiveDependency,
        'streamDependency': streamDependency,
        'weight': weight,
      });
}

class RstStreamFrame extends Frame {
  static const int FIXED_FRAME_LENGTH = 4;

  final int errorCode;

  RstStreamFrame(super.header, this.errorCode);

  @override
  Map toJson() => super.toJson()..addAll({'errorCode': errorCode});
}

class Setting {
  static const int SETTINGS_HEADER_TABLE_SIZE = 1;
  static const int SETTINGS_ENABLE_PUSH = 2;
  static const int SETTINGS_MAX_CONCURRENT_STREAMS = 3;
  static const int SETTINGS_INITIAL_WINDOW_SIZE = 4;
  static const int SETTINGS_MAX_FRAME_SIZE = 5;
  static const int SETTINGS_MAX_HEADER_LIST_SIZE = 6;

  final int identifier;
  final int value;

  Setting(this.identifier, this.value);

  Map toJson() => {'identifier': identifier, 'value': value};
}

class SettingsFrame extends Frame {
  static const int FLAG_ACK = 0x1;

  // A setting consist of a 2 byte identifier and a 4 byte value.
  static const int SETTING_SIZE = 6;

  final List<Setting> settings;

  SettingsFrame(super.header, this.settings);

  bool get hasAckFlag => _isFlagSet(header.flags, FLAG_ACK);

  @override
  Map toJson() =>
      super.toJson()
        ..addAll({'settings': settings.map((s) => s.toJson()).toList()});
}

class PushPromiseFrame extends Frame {
  static const int FLAG_END_HEADERS = 0x4;
  static const int FLAG_PADDED = 0x8;

  // NOTE: This is the size a [PushPromiseFrame] can have in addition to padding
  // and header block fragment data.
  static const int MAX_CONSTANT_PAYLOAD = 5;

  final int padLength;
  final int promisedStreamId;
  final List<int> headerBlockFragment;

  /// This will be set from the outside after decoding.
  late List<Header> decodedHeaders;

  PushPromiseFrame(
    super.header,
    this.padLength,
    this.promisedStreamId,
    this.headerBlockFragment,
  );

  bool get hasEndHeadersFlag => _isFlagSet(header.flags, FLAG_END_HEADERS);
  bool get hasPaddedFlag => _isFlagSet(header.flags, FLAG_PADDED);

  PushPromiseFrame addBlockContinuation(ContinuationFrame frame) {
    var fragment = frame.headerBlockFragment;
    var flags = header.flags | frame.header.flags;
    var fh = FrameHeader(
      header.length + fragment.length,
      header.type,
      flags,
      header.streamId,
    );

    var mergedHeaderBlockFragment = Uint8List(
      headerBlockFragment.length + fragment.length,
    );

    mergedHeaderBlockFragment.setRange(
      0,
      headerBlockFragment.length,
      headerBlockFragment,
    );

    mergedHeaderBlockFragment.setRange(
      headerBlockFragment.length,
      mergedHeaderBlockFragment.length,
      fragment,
    );

    return PushPromiseFrame(
      fh,
      padLength,
      promisedStreamId,
      mergedHeaderBlockFragment,
    );
  }

  @override
  Map toJson() =>
      super.toJson()..addAll({
        'padLength': padLength,
        'promisedStreamId': promisedStreamId,
        'headerBlockFragment (len)': headerBlockFragment.length,
      });
}

class PingFrame extends Frame {
  static const int FIXED_FRAME_LENGTH = 8;

  static const int FLAG_ACK = 0x1;

  final int opaqueData;

  PingFrame(super.header, this.opaqueData);

  bool get hasAckFlag => _isFlagSet(header.flags, FLAG_ACK);

  @override
  Map toJson() => super.toJson()..addAll({'opaqueData': opaqueData});
}

class GoawayFrame extends Frame {
  final int lastStreamId;
  final int errorCode;
  final List<int> debugData;

  GoawayFrame(super.header, this.lastStreamId, this.errorCode, this.debugData);

  @override
  Map toJson() =>
      super.toJson()..addAll({
        'lastStreamId': lastStreamId,
        'errorCode': errorCode,
        'debugData (length)': debugData.length,
      });
}

class WindowUpdateFrame extends Frame {
  static const int FIXED_FRAME_LENGTH = 4;

  final int windowSizeIncrement;

  WindowUpdateFrame(super.header, this.windowSizeIncrement);

  @override
  Map toJson() =>
      super.toJson()..addAll({'windowSizeIncrement': windowSizeIncrement});
}

class ContinuationFrame extends Frame {
  static const int FLAG_END_HEADERS = 0x4;

  final List<int> headerBlockFragment;

  ContinuationFrame(super.header, this.headerBlockFragment);

  bool get hasEndHeadersFlag => _isFlagSet(header.flags, FLAG_END_HEADERS);

  @override
  Map toJson() =>
      super.toJson()
        ..addAll({'headerBlockFragment (length)': headerBlockFragment.length});
}

class UnknownFrame extends Frame {
  final List<int> data;

  UnknownFrame(super.header, this.data);

  @override
  Map toJson() => super.toJson()..addAll({'data (length)': data.length});
}
