// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show StreamController, StreamSink;
import 'dart:developer' show addHttpClientProfilingData, Timeline;
import 'dart:io';

/// Describes an event related to an HTTP request.
final class HttpProfileRequestEvent {
  final int _timestamp;
  final String _name;

  /// [timestamp] should be the time at which the event occurred, as a
  /// microsecond value on the monotonic clock used by the [Timeline].
  HttpProfileRequestEvent({required int timestamp, required String name})
      : _timestamp = timestamp,
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

  HttpProfileProxyData(
      {String? host, String? username, bool? isDirect, int? port})
      : _host = host,
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

/// Describes details about an HTTP request.
final class HttpProfileRequestData {
  final Map<String, dynamic> _data;

  final void Function() _updated;

  /// The elements of [connectionInfo] can either be [String]s or [int]s.
  set connectionInfo(Map<String, dynamic /*String|int*/ > value) {
    _data['connectionInfo'] = value;
    _updated();
  }

  /// The content length of the request, in bytes.
  set contentLength(int value) {
    _data['contentLength'] = value;
    _updated();
  }

  /// The cookies presented to the server (in the 'cookie' header).
  set cookies(List<String> value) {
    _data['cookies'] = value;
    _updated();
  }

  /// The error associated with the failed request.
  set error(String value) {
    _data['error'] = value;
    _updated();
  }

  /// Whether redirects were followed automatically.
  set followRedirects(bool value) {
    _data['followRedirects'] = value;
    _updated();
  }

  set headers(Map<String, List<String>> value) {
    _data['headers'] = value;
    _updated();
  }

  /// If [followRedirects] is true, this is the maximum number of redirects that
  /// were followed.
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

  HttpProfileRequestData._(
      Map<String, dynamic> this._data, void Function() this._updated);
}

/// Describes details about a response to an HTTP request.
final class HttpProfileResponseData {
  final Map<String, dynamic> _data;

  final void Function() _updated;

  /// Records a redirect that the connection went through. The elements of
  /// [redirect] can either be [String]s or [int]s.
  void addRedirect(Map<String, dynamic /*String|int*/ > redirect) {
    _data['redirects'].add(redirect);
    _updated();
  }

  /// The cookies set by the server (from the 'set-cookie' header).
  set cookies(List<String> value) {
    _data['cookies'] = value;
    _updated();
  }

  /// The elements of [connectionInfo] can either be [String]s or [int]s.
  set connectionInfo(Map<String, dynamic /*String|int*/ > value) {
    _data['connectionInfo'] = value;
    _updated();
  }

  set headers(Map<String, List<String>> value) {
    _data['headers'] = value;
    _updated();
  }

  // The compression state of the response.
  //
  // This specifies whether the response bytes were compressed when they were
  // received across the wire and whether callers will receive compressed or
  // uncompressed bytes when they listen to the response body byte stream.
  set compressionState(String value) {
    _data['compressionState'] = value;
    _updated();
  }

  set reasonPhrase(String value) {
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

  /// The time at which the initial response was received, as a microsecond
  /// value on the monotonic clock used by the [Timeline].
  set startTime(int value) {
    _data['startTime'] = value;
    _updated();
  }

  /// The time at which the response was completed, as a microsecond value on
  /// the monotonic clock used by the [Timeline]. Note that DevTools will not
  /// consider the request to be complete until [endTime] is non-null.
  set endTime(int value) {
    _data['endTime'] = value;
    _updated();
  }

  /// The error associated with the failed request.
  set error(String value) {
    _data['error'] = value;
    _updated();
  }

  HttpProfileResponseData._(
      Map<String, dynamic> this._data, void Function() this._updated) {
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

  /// The ID of the isolate the request was issued from.
  String? get isolateId => _data['isolateId'] as String?;
  set isolateId(String? value) {
    _data['isolateId'] = value;
    _updated();
  }

  /// The HTTP request method associated with the request.
  String? get requestMethod => _data['requestMethod'] as String?;
  set requestMethod(String? value) {
    _data['requestMethod'] = value;
    _updated();
  }

  /// The URI to which the request was sent.
  String? get requestUri => _data['requestUri'] as String?;
  set requestUri(String? value) {
    _data['requestUri'] = value;
    _updated();
  }

  /// Records an event related to the request.
  ///
  /// Usage example:
  ///
  /// ```dart
  /// profile.addEvent(HttpProfileRequestEvent(Timeline.now, "Connection Established");
  /// profile.addEvent(HttpProfileRequestEvent(Timeline.now, "Remote Disconnected");
  /// ```
  void addEvent(HttpProfileRequestEvent event) {
    _data['events'].add(event._toJson());
    _updated();
  }

  /// The time at which the request was initiated, as a microsecond value on the
  /// monotonic clock used by the [Timeline].
  int? get requestStartTimestamp => _data['requestStartTimestamp'] as int?;
  set requestStartTimestamp(int? value) {
    _data['requestStartTimestamp'] = value;
    _updated();
  }

  /// The time at which the request was completed, as a microsecond value on the
  /// monotonic clock used by the [Timeline]. Note that DevTools will not
  /// consider the request to be complete until [requestEndTimestamp] is
  /// non-null.
  int? get requestEndTimestamp => _data['requestEndTimestamp'] as int?;
  set requestEndTimestamp(int? value) {
    _data['requestEndTimestamp'] = value;
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

  HttpClientRequestProfile._() {
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
    _data['_lastUpdateTime'] = 0;
  }

  /// If HTTP profiling is enabled, returns an [HttpClientRequestProfile],
  /// otherwise returns `null`.
  static HttpClientRequestProfile? profile() {
    // Always return `null` in product mode so that the profiling code can be
    // tree shaken away.
    if (const bool.fromEnvironment('dart.vm.product') || !profilingEnabled) {
      return null;
    }
    final requestProfile = HttpClientRequestProfile._();
    // This entry is needed to support the id parameter of
    // ext.dart.io.getHttpProfileRequest.
    requestProfile._data['id'] =
        'from_package/${addHttpClientProfilingData(requestProfile._data)}';
    return requestProfile;
  }
}
