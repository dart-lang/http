// Autogenerated from Pigeon (v3.2.3), do not edit directly.
// See also: https://pub.dev/packages/pigeon
// ignore_for_file: public_member_api_docs, non_constant_identifier_names, avoid_as, unused_import, unnecessary_parenthesis, prefer_null_aware_operators, omit_local_variable_types, unused_shown_name, unnecessary_import
import 'dart:async';
import 'dart:typed_data' show Uint8List, Int32List, Int64List, Float64List;

import 'package:flutter/foundation.dart' show WriteBuffer, ReadBuffer;
import 'package:flutter/services.dart';

enum EventMessageType {
  responseStarted,
  readCompleted,
  tooManyRedirects,
}

class ResponseStarted {
  ResponseStarted({
    required this.headers,
    required this.statusCode,
    required this.isRedirect,
  });

  Map<String?, List<String?>?> headers;
  int statusCode;
  bool isRedirect;

  Object encode() {
    final Map<Object?, Object?> pigeonMap = <Object?, Object?>{};
    pigeonMap['headers'] = headers;
    pigeonMap['statusCode'] = statusCode;
    pigeonMap['isRedirect'] = isRedirect;
    return pigeonMap;
  }

  static ResponseStarted decode(Object message) {
    final Map<Object?, Object?> pigeonMap = message as Map<Object?, Object?>;
    return ResponseStarted(
      headers: (pigeonMap['headers'] as Map<Object?, Object?>?)!.cast<String?, List<String?>?>(),
      statusCode: pigeonMap['statusCode']! as int,
      isRedirect: pigeonMap['isRedirect']! as bool,
    );
  }
}

class ReadCompleted {
  ReadCompleted({
    required this.data,
  });

  Uint8List data;

  Object encode() {
    final Map<Object?, Object?> pigeonMap = <Object?, Object?>{};
    pigeonMap['data'] = data;
    return pigeonMap;
  }

  static ReadCompleted decode(Object message) {
    final Map<Object?, Object?> pigeonMap = message as Map<Object?, Object?>;
    return ReadCompleted(
      data: pigeonMap['data']! as Uint8List,
    );
  }
}

class EventMessage {
  EventMessage({
    required this.type,
    this.responseStarted,
    this.readCompleted,
  });

  EventMessageType type;
  ResponseStarted? responseStarted;
  ReadCompleted? readCompleted;

  Object encode() {
    final Map<Object?, Object?> pigeonMap = <Object?, Object?>{};
    pigeonMap['type'] = type.index;
    pigeonMap['responseStarted'] = responseStarted?.encode();
    pigeonMap['readCompleted'] = readCompleted?.encode();
    return pigeonMap;
  }

  static EventMessage decode(Object message) {
    final Map<Object?, Object?> pigeonMap = message as Map<Object?, Object?>;
    return EventMessage(
      type: EventMessageType.values[pigeonMap['type']! as int]
,
      responseStarted: pigeonMap['responseStarted'] != null
          ? ResponseStarted.decode(pigeonMap['responseStarted']!)
          : null,
      readCompleted: pigeonMap['readCompleted'] != null
          ? ReadCompleted.decode(pigeonMap['readCompleted']!)
          : null,
    );
  }
}

class StartRequest {
  StartRequest({
    required this.url,
    required this.method,
    required this.headers,
    required this.body,
    required this.maxRedirects,
    required this.followRedirects,
  });

  String url;
  String method;
  Map<String?, String?> headers;
  Uint8List body;
  int maxRedirects;
  bool followRedirects;

  Object encode() {
    final Map<Object?, Object?> pigeonMap = <Object?, Object?>{};
    pigeonMap['url'] = url;
    pigeonMap['method'] = method;
    pigeonMap['headers'] = headers;
    pigeonMap['body'] = body;
    pigeonMap['maxRedirects'] = maxRedirects;
    pigeonMap['followRedirects'] = followRedirects;
    return pigeonMap;
  }

  static StartRequest decode(Object message) {
    final Map<Object?, Object?> pigeonMap = message as Map<Object?, Object?>;
    return StartRequest(
      url: pigeonMap['url']! as String,
      method: pigeonMap['method']! as String,
      headers: (pigeonMap['headers'] as Map<Object?, Object?>?)!.cast<String?, String?>(),
      body: pigeonMap['body']! as Uint8List,
      maxRedirects: pigeonMap['maxRedirects']! as int,
      followRedirects: pigeonMap['followRedirects']! as bool,
    );
  }
}

class StartResponse {
  StartResponse({
    required this.eventChannel,
  });

  String eventChannel;

  Object encode() {
    final Map<Object?, Object?> pigeonMap = <Object?, Object?>{};
    pigeonMap['eventChannel'] = eventChannel;
    return pigeonMap;
  }

  static StartResponse decode(Object message) {
    final Map<Object?, Object?> pigeonMap = message as Map<Object?, Object?>;
    return StartResponse(
      eventChannel: pigeonMap['eventChannel']! as String,
    );
  }
}

class _HttpApiCodec extends StandardMessageCodec {
  const _HttpApiCodec();
  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is EventMessage) {
      buffer.putUint8(128);
      writeValue(buffer, value.encode());
    } else 
    if (value is ReadCompleted) {
      buffer.putUint8(129);
      writeValue(buffer, value.encode());
    } else 
    if (value is ResponseStarted) {
      buffer.putUint8(130);
      writeValue(buffer, value.encode());
    } else 
    if (value is StartRequest) {
      buffer.putUint8(131);
      writeValue(buffer, value.encode());
    } else 
    if (value is StartResponse) {
      buffer.putUint8(132);
      writeValue(buffer, value.encode());
    } else 
{
      super.writeValue(buffer, value);
    }
  }
  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    switch (type) {
      case 128:       
        return EventMessage.decode(readValue(buffer)!);
      
      case 129:       
        return ReadCompleted.decode(readValue(buffer)!);
      
      case 130:       
        return ResponseStarted.decode(readValue(buffer)!);
      
      case 131:       
        return StartRequest.decode(readValue(buffer)!);
      
      case 132:       
        return StartResponse.decode(readValue(buffer)!);
      
      default:      
        return super.readValueOfType(type, buffer);
      
    }
  }
}

class HttpApi {
  /// Constructor for [HttpApi].  The [binaryMessenger] named argument is
  /// available for dependency injection.  If it is left null, the default
  /// BinaryMessenger will be used which routes to the host platform.
  HttpApi({BinaryMessenger? binaryMessenger}) : _binaryMessenger = binaryMessenger;

  final BinaryMessenger? _binaryMessenger;

  static const MessageCodec<Object?> codec = _HttpApiCodec();

  Future<StartResponse> start(StartRequest arg_request) async {
    final BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.HttpApi.start', codec, binaryMessenger: _binaryMessenger);
    final Map<Object?, Object?>? replyMap =
        await channel.send(<Object?>[arg_request]) as Map<Object?, Object?>?;
    if (replyMap == null) {
      throw PlatformException(
        code: 'channel-error',
        message: 'Unable to establish connection on channel.',
      );
    } else if (replyMap['error'] != null) {
      final Map<Object?, Object?> error = (replyMap['error'] as Map<Object?, Object?>?)!;
      throw PlatformException(
        code: (error['code'] as String?)!,
        message: error['message'] as String?,
        details: error['details'],
      );
    } else if (replyMap['result'] == null) {
      throw PlatformException(
        code: 'null-error',
        message: 'Host platform returned null value for non-null return value.',
      );
    } else {
      return (replyMap['result'] as StartResponse?)!;
    }
  }

  Future<void> dummy(EventMessage arg_message) async {
    final BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.HttpApi.dummy', codec, binaryMessenger: _binaryMessenger);
    final Map<Object?, Object?>? replyMap =
        await channel.send(<Object?>[arg_message]) as Map<Object?, Object?>?;
    if (replyMap == null) {
      throw PlatformException(
        code: 'channel-error',
        message: 'Unable to establish connection on channel.',
      );
    } else if (replyMap['error'] != null) {
      final Map<Object?, Object?> error = (replyMap['error'] as Map<Object?, Object?>?)!;
      throw PlatformException(
        code: (error['code'] as String?)!,
        message: error['message'] as String?,
        details: error['details'],
      );
    } else {
      return;
    }
  }
}
