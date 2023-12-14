// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show StreamController, StreamSink;
import 'dart:developer' show addHttpClientProfilingData, Service, Timeline;
import 'dart:io' show HttpClient, HttpClientResponseCompressionState;
import 'dart:isolate' show Isolate;

/// Describes an event related to an HTTP request.
final class HttpProfileRequestEvent {
  final int _timestamp;
  final String _name;

  HttpProfileRequestEvent({required DateTime timestamp, required String name})
      : _timestamp = timestamp.microsecondsSinceEpoch,
        _name = name;

  Map<String, dynamic> _toJson() => <String, dynamic>{
        'timestamp': _timestamp,
        'event': _name,
      };
}

/// Describes proxy authentication details associated with an HTTP request.
final class HttpProfileProxyData {
  final String? _host;
  final String? _username;
  final bool? _isDirect;
  final int? _port;

  HttpProfileProxyData({
    String? host,
    String? username,
    bool? isDirect,
    int? port,
  })  : _host = host,
        _username = username,
        _isDirect = isDirect,
        _port = port;

  Map<String, dynamic> _toJson() => <String, dynamic>{
        if (_host != null) 'host': _host,
        if (_username != null) 'username': _username,
        if (_isDirect != null) 'isDirect': _isDirect,
        if (_port != null) 'port': _port,
      };
}

/// Describes a redirect that an HTTP connection went through.
class HttpProfileRedirectData {
  int _statusCode;
  String _method;
  String _location;

  HttpProfileRedirectData({
    required int statusCode,
    required String method,
    required String location,
  })  : _statusCode = statusCode,
        _method = method,
        _location = location;

  Map<String, dynamic> _toJson() => <String, dynamic>{
        'statusCode': _statusCode,
        'method': _method,
        'location': _location,
      };
}

/// Describes details about an HTTP request.
final class HttpProfileRequestData {
  final Map<String, dynamic> _data;

  final void Function() _updated;

  /// Information about the networking connection used in the HTTP request.
  ///
  /// This information is meant to be used for debugging.
  ///
  /// It can contain any arbitrary data as long as the values are of type
  /// [String] or [int]. For example:
  /// { 'localPort': 1285, 'remotePort': 443, 'connectionPoolId': '21x23' }
  set connectionInfo(Map<String, dynamic /*String|int*/ > value) {
    for (final v in value.values) {
      if (!(v is String || v is int)) {
        throw ArgumentError(
            "The values in connectionInfo must be of type String or int.");
      }
    }
    _data['connectionInfo'] = {...value};
    _updated();
  }

  /// The content length of the request, in bytes.
  set contentLength(int? value) {
    if (value == null) {
      _data.remove('contentLength');
    } else {
      _data['contentLength'] = value;
    }
    _updated();
  }

  /// The cookies presented to the server (in the 'cookie' header).
  ///
  /// XXX Can have multiple values in the same item.
  /// Usage example:
  ///
  /// ```dart
  /// profile.requestData.cookies = [
  ///   'sessionId=abc123',
  ///   'csrftoken=def456',
  /// ];
  ///
  /// or
  ///
  /// profile.requestData.cookies = ['sessionId=abc123,csrftoken=def456']
  /// ```
  set cookiesList(List<String>? value) {
    if (value == null) {
      _data.remove('cookies');
    }
    _data['cookies'] = [...value];
    _updated();
  }

  set cookies(String value) {
    if (value == null) {
      _data.remove('cookies');
    }
    _data['cookies'] = ",".split(RegExp(r'\s*,\s*'))
    _updated();
  }

  /// The error associated with a failed request.
  ///
  /// Should this be here? It doesn't just seem asssociated with the request.
  set error(String value) {
    _data['error'] = value;
    _updated();
  }

  /// Whether automatic redirect following was enabled for the request.
  set followRedirects(bool value) {
    _data['followRedirects'] = value;
    _updated();
  }

  set headersValueList(Map<String, List<String>>? value) {
    if (value == null) {
      _data.remove('headers');
    }
    _data['headers'] = {...value};
    _updated();
  }

  /// XXX should this include cookies or not? It's not obvious why we seperate
  /// cookies from other headers.
  set headers(Map<String, String>? value) {
    if (value == null) {
      _data.remove('headers');
    }
    _data['headers'] = {for (var entry in value.entries) entry.key : entry.value.split(RegExp(r'\s*,\s*'))};
    _updated();
  }

  /// The maximum number of redirects allowed during the request.
  set maxRedirects(int value) {
    _data['maxRedirects'] = value;
    _updated();
  }

  /// The requested persistent connection state.
  set persistentConnection(bool value) {
    _data['persistentConnection'] = value;
    _updated();
  }

  /// Proxy authentication details for the request.
  set proxyDetails(HttpProfileProxyData value) {
    _data['proxyDetails'] = value._toJson();
    _updated();
  }

  const HttpProfileRequestData._(
    Map<String, dynamic> this._data,
    void Function() this._updated,
  );
}

/// Describes details about a response to an HTTP request.
final class HttpProfileResponseData {
  final Map<String, dynamic> _data;

  final void Function() _updated;

  /// Records a redirect that the connection went through.
  void addRedirect(HttpProfileRedirectData redirect) {
    _data['redirects'].add(redirect._toJson());
    _updated();
  }

  /// The cookies set by the server (from the 'set-cookie' header).
  ///
  /// Usage example:
  ///
  /// ```dart
  /// profile.responseData.cookies = [
  ///   'sessionId=abc123',
  ///   'id=def456; Max-Age=2592000; Domain=example.com',
  /// ];
  /// ```
  set cookies(List<String> value) {
    _data['cookies'] = [...value];
    _updated();
  }

  /// Information about the networking connection used in the HTTP response.
  ///
  /// This information is meant to be used for debugging.
  ///
  /// It can contain any arbitrary data as long as the values are of type
  /// [String] or [int]. For example:
  /// { 'localPort': 1285, 'remotePort': 443, 'connectionPoolId': '21x23' }
  /// 
  /// XXX what is the difference between the connection info in the request
  /// and the response? Don't they use the same connection?
  set connectionInfo(Map<String, dynamic /*String|int*/ > value) {
    for (final v in value.values) {
      if (!(v is String || v is int)) {
        throw ArgumentError(
            "The values in connectionInfo must be of type String or int.");
      }
    }
    _data['connectionInfo'] = {...value};
    _updated();
  }

  set headers(Map<String, List<String>> value) {
    _data['headers'] = {...value};
    _updated();
  }

  // The compression state of the response.
  //
  // This specifies whether the response bytes were compressed when they were
  // received across the wire and whether callers will receive compressed or
  // uncompressed bytes when they listen to the response body byte stream.
  set compressionState(HttpClientResponseCompressionState value) {
    _data['compressionState'] = value.name;
    _updated();
  }

  set reasonPhrase(String? value) {
    if (value == null) {
      _data.remove('reasonPhrase');
    }
    _data['reasonPhrase'] = value;
    _updated();
  }

  /// Whether the status code was one of the normal redirect codes.
  set isRedirect(bool value) {
    _data['isRedirect'] = value;
    _updated();
  }

  /// The persistent connection state returned by the server.
  set persistentConnection(bool value) {
    _data['persistentConnection'] = value;
    _updated();
  }

  /// The content length of the response body, in bytes.
  set contentLength(int value) {
    _data['contentLength'] = value;
    _updated();
  }

  set statusCode(int value) {
    _data['statusCode'] = value;
    _updated();
  }

  /// The time at which the initial response was received.
  set startTime(DateTime value) {
    _data['startTime'] = value.microsecondsSinceEpoch;
    _updated();
  }

  /// The time at which the response was completed. Note that DevTools will not
  /// consider the request to be complete until [endTime] is non-null.
  ///
  /// This means that all the data has been received, right?
  set endTime(DateTime value) {
    _data['endTime'] = value.microsecondsSinceEpoch;
    _updated();
  }

  /// The error associated with a failed request.
  ///
  /// This doesn't seem to be just set for failures. For HttpClient,
  /// finishResponseWithError('Connection was upgraded')
  set error(String value) {
    _data['error'] = value;
    _updated();
  }

  HttpProfileResponseData._(
    Map<String, dynamic> this._data,
    void Function() this._updated,
  ) {
    _data['redirects'] = <Map<String, dynamic>>[];
  }
}

/// A record of debugging information about an HTTP request.
final class HttpClientRequestProfile {
  /// Whether HTTP profiling is enabled or not.
  ///
  /// The value can be changed programmatically or through the DevTools Network
  /// UX.
  static bool get profilingEnabled => HttpClient.enableTimelineLogging;
  static set profilingEnabled(bool enabled) =>
      HttpClient.enableTimelineLogging = enabled;

  final _data = <String, dynamic>{};

  /// Records an event related to the request.
  ///
  /// Usage example:
  ///
  /// ```dart
  /// profile.addEvent(HttpProfileRequestEvent(DateTime.now(), "Connection Established");
  /// profile.addEvent(HttpProfileRequestEvent(DateTime.now(), "Remote Disconnected");
  /// ```
  void addEvent(HttpProfileRequestEvent event) {
    _data['events'].add(event._toJson());
    _updated();
  }

  /// The time at which the request was completed. Note that DevTools will not
  /// consider the request to be complete until [requestEndTimestamp] is
  /// non-null.
  ///
  /// What does this mean? Is it when the response data first arrives? Or
  /// after the initial request data has been sent? This matters because do
  /// redirects count as part of the request time?
  set requestEndTimestamp(DateTime value) {
    _data['requestEndTimestamp'] = value.microsecondsSinceEpoch;
    _updated();
  }

  /// Details about the request.
  late final HttpProfileRequestData requestData;

  final StreamController<List<int>> _requestBody =
      StreamController<List<int>>();

  /// The body of the request.
  StreamSink<List<int>> get requestBodySink {
    _updated();
    return _requestBody.sink;
  }

  /// Details about the response.
  late final HttpProfileResponseData responseData;

  final StreamController<List<int>> _responseBody =
      StreamController<List<int>>();

  /// The body of the response.
  StreamSink<List<int>> get responseBodySink {
    _updated();
    return _responseBody.sink;
  }

  void _updated() => _data['_lastUpdateTime'] = Timeline.now;

  HttpClientRequestProfile._({
    required DateTime requestStartTimestamp,
    required String requestMethod,
    required String requestUri,
  }) {
    _data['isolateId'] = Service.getIsolateId(Isolate.current)!;
    _data['requestStartTimestamp'] =
        requestStartTimestamp.microsecondsSinceEpoch;
    _data['requestMethod'] = requestMethod;
    _data['requestUri'] = requestUri;
    _data['events'] = <Map<String, dynamic>>[];
    _data['requestData'] = <String, dynamic>{};
    requestData = HttpProfileRequestData._(
        _data['requestData'] as Map<String, dynamic>, _updated);
    _data['responseData'] = <String, dynamic>{};
    responseData = HttpProfileResponseData._(
        _data['responseData'] as Map<String, dynamic>, _updated);
    _data['_requestBodyStream'] = _requestBody.stream;
    _data['_responseBodyStream'] = _responseBody.stream;
    // This entry is needed to support the updatedSince parameter of
    // ext.dart.io.getHttpProfile.
    _data['_lastUpdateTime'] = Timeline.now;
  }

  /// If HTTP profiling is enabled, returns an [HttpClientRequestProfile],
  /// otherwise returns `null`.
  static HttpClientRequestProfile? profile({
    /// The time at which the request was initiated.
    required DateTime requestStartTimestamp,

    /// The HTTP request method associated with the request.
    required String requestMethod,

    /// The URI to which the request was sent.
    required String requestUri,
  }) {
    // Always return `null` in product mode so that the profiling code can be
    // tree shaken away.
    if (const bool.fromEnvironment('dart.vm.product') || !profilingEnabled) {
      return null;
    }
    final requestProfile = HttpClientRequestProfile._(
      requestStartTimestamp: requestStartTimestamp,
      requestMethod: requestMethod,
      requestUri: requestUri,
    );
    // This entry is needed to support the id parameter of
    // ext.dart.io.getHttpProfileRequest.
    requestProfile._data['id'] =
        addHttpClientProfilingData(requestProfile._data);
    return requestProfile;
  }
}
