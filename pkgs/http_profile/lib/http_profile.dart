// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show StreamController, StreamSink;
import 'dart:developer' show Service, addHttpClientProfilingData;
import 'dart:io' show HttpClient, HttpClientResponseCompressionState;
import 'dart:isolate' show Isolate;

/// "token" as defined in RFC 2616, 2.2
/// See https://datatracker.ietf.org/doc/html/rfc2616#section-2.2
const _tokenChars = r"!#$%&'*+\-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ^_`"
    'abcdefghijklmnopqrstuvwxyz|~';

/// Splits comma-separated header values.
var _headerSplitter = RegExp(r'[ \t]*,[ \t]*');

/// Splits comma-separated "Set-Cookie" header values.
///
/// Set-Cookie strings can contain commas. In particular, the following
/// productions defined in RFC-6265, section 4.1.1:
/// - <sane-cookie-date> e.g. "Expires=Sun, 06 Nov 1994 08:49:37 GMT"
/// - <path-value> e.g. "Path=somepath,"
/// - <extension-av> e.g. "AnyString,Really,"
///
/// Some values are ambiguous e.g.
/// "Set-Cookie: lang=en; Path=/foo/"
/// "Set-Cookie: SID=x23"
/// and:
/// "Set-Cookie: lang=en; Path=/foo/,SID=x23"
/// would both be result in `response.headers` => "lang=en; Path=/foo/,SID=x23"
///
/// The idea behind this regex is that ",<valid token>=" is more likely to
/// start a new <cookie-pair> then be part of <path-value> or <extension-av>.
///
/// See https://datatracker.ietf.org/doc/html/rfc6265#section-4.1.1
var _setCookieSplitter = RegExp(r'[ \t]*,[ \t]*(?=[' + _tokenChars + r']+=)');

/// Splits comma-separated header values into a [List].
///
/// Copied from `package:http`.
Map<String, List<String>> _splitHeaderValues(Map<String, String> headers) {
  var headersWithFieldLists = <String, List<String>>{};
  headers.forEach((key, value) {
    if (!value.contains(',')) {
      headersWithFieldLists[key] = [value];
    } else {
      if (key == 'set-cookie') {
        headersWithFieldLists[key] = value.split(_setCookieSplitter);
      } else {
        headersWithFieldLists[key] = value.split(_headerSplitter);
      }
    }
  });
  return headersWithFieldLists;
}

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
  final int _statusCode;
  final String _method;
  final String _location;

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
  final StreamController<List<int>> _body = StreamController<List<int>>();
  bool _isClosed = false;
  final void Function() _updated;

  Map<String, dynamic> get _requestData =>
      _data['requestData'] as Map<String, dynamic>;

  /// The body of the request.
  StreamSink<List<int>> get bodySink => _body.sink;

  /// Information about the networking connection used in the HTTP request.
  ///
  /// This information is meant to be used for debugging.
  ///
  /// It can contain any arbitrary data as long as the values are of type
  /// [String] or [int]. For example:
  /// { 'localPort': 1285, 'remotePort': 443, 'connectionPoolId': '21x23' }
  set connectionInfo(Map<String, dynamic /*String|int*/ > value) {
    _checkAndUpdate();
    for (final v in value.values) {
      if (!(v is String || v is int)) {
        throw ArgumentError(
          'The values in connectionInfo must be of type String or int.',
        );
      }
    }
    _requestData['connectionInfo'] = {...value};
  }

  /// The content length of the request, in bytes.
  set contentLength(int? value) {
    _checkAndUpdate();
    if (value == null) {
      _requestData.remove('contentLength');
    } else {
      _requestData['contentLength'] = value;
    }
  }

  /// Whether automatic redirect following was enabled for the request.
  set followRedirects(bool value) {
    _checkAndUpdate();
    _requestData['followRedirects'] = value;
  }

  /// The request headers where duplicate headers are represented using a list
  /// of values.
  ///
  /// For example:
  ///
  /// ```dart
  /// // Foo: Bar
  /// // Foo: Baz
  ///
  /// profile?.requestData.headersListValues({'Foo', ['Bar', 'Baz']});
  /// ```
  set headersListValues(Map<String, List<String>>? value) {
    _checkAndUpdate();
    if (value == null) {
      _requestData.remove('headers');
      return;
    }
    _requestData['headers'] = {...value};
  }

  /// The request headers where duplicate headers are represented using a
  /// comma-separated list of values.
  ///
  /// For example:
  ///
  /// ```dart
  /// // Foo: Bar
  /// // Foo: Baz
  ///
  /// profile?.requestData.headersCommaValues({'Foo', 'Bar, Baz']});
  /// ```
  set headersCommaValues(Map<String, String>? value) {
    _checkAndUpdate();
    if (value == null) {
      _requestData.remove('headers');
      return;
    }
    _requestData['headers'] = _splitHeaderValues(value);
  }

  /// The maximum number of redirects allowed during the request.
  set maxRedirects(int value) {
    _checkAndUpdate();
    _requestData['maxRedirects'] = value;
  }

  /// The requested persistent connection state.
  set persistentConnection(bool value) {
    _checkAndUpdate();
    _requestData['persistentConnection'] = value;
  }

  /// Proxy authentication details for the request.
  set proxyDetails(HttpProfileProxyData value) {
    _checkAndUpdate();
    _requestData['proxyDetails'] = value._toJson();
  }

  HttpProfileRequestData._(
    this._data,
    this._updated,
  );

  void _checkAndUpdate() {
    if (_isClosed) {
      throw StateError('HttpProfileResponseData has been closed, no further '
          'updates are allowed');
    }
    _updated();
  }

  /// Signal that the request, including the entire request body, has been
  /// sent.
  ///
  /// [bodySink] will be closed and the fields of [HttpProfileRequestData] will
  /// no longer be changeable.
  ///
  /// [endTime] is the time when the request was fully sent. It defaults to the
  /// current time.
  void close([DateTime? endTime]) {
    _checkAndUpdate();
    _isClosed = true;
    bodySink.close();
    _data['requestEndTimestamp'] =
        (endTime ?? DateTime.now()).microsecondsSinceEpoch;
  }

  /// Signal that sending the request has failed with an error.
  ///
  /// [bodySink] will be closed and the fields of [HttpProfileRequestData] will
  /// no longer be changeable.
  ///
  /// [value] is a textual description of the error e.g. 'host does not exist'.
  ///
  /// [endTime] is the time when the error occurred. It defaults to the current
  /// time.
  void closeWithError(String value, [DateTime? endTime]) {
    _checkAndUpdate();
    _isClosed = true;
    bodySink.close();
    _requestData['error'] = value;
    _data['requestEndTimestamp'] =
        (endTime ?? DateTime.now()).microsecondsSinceEpoch;
  }
}

/// Describes details about a response to an HTTP request.
final class HttpProfileResponseData {
  bool _isClosed = false;
  final Map<String, dynamic> _data;
  final void Function() _updated;
  final StreamController<List<int>> _body = StreamController<List<int>>();

  /// Records a redirect that the connection went through.
  void addRedirect(HttpProfileRedirectData redirect) {
    _checkAndUpdate();
    (_data['redirects'] as List<Map<String, dynamic>>).add(redirect._toJson());
  }

  /// The body of the response.
  StreamSink<List<int>> get bodySink => _body.sink;

  /// Information about the networking connection used in the HTTP response.
  ///
  /// This information is meant to be used for debugging.
  ///
  /// It can contain any arbitrary data as long as the values are of type
  /// [String] or [int]. For example:
  /// { 'localPort': 1285, 'remotePort': 443, 'connectionPoolId': '21x23' }
  set connectionInfo(Map<String, dynamic /*String|int*/ > value) {
    _checkAndUpdate();
    for (final v in value.values) {
      if (!(v is String || v is int)) {
        throw ArgumentError(
          'The values in connectionInfo must be of type String or int.',
        );
      }
    }
    _data['connectionInfo'] = {...value};
  }

  /// The reponse headers where duplicate headers are represented using a list
  /// of values.
  ///
  /// For example:
  ///
  /// ```dart
  /// // Foo: Bar
  /// // Foo: Baz
  ///
  /// profile?.requestData.headersListValues({'Foo', ['Bar', 'Baz']});
  /// ```
  set headersListValues(Map<String, List<String>>? value) {
    _checkAndUpdate();
    if (value == null) {
      _data.remove('headers');
      return;
    }
    _data['headers'] = {...value};
  }

  /// The response headers where duplicate headers are represented using a
  /// comma-separated list of values.
  ///
  /// For example:
  ///
  /// ```dart
  /// // Foo: Bar
  /// // Foo: Baz
  ///
  /// profile?.responseData.headersCommaValues({'Foo', 'Bar, Baz']});
  /// ```
  set headersCommaValues(Map<String, String>? value) {
    _checkAndUpdate();
    if (value == null) {
      _data.remove('headers');
      return;
    }
    _data['headers'] = _splitHeaderValues(value);
  }

  // The compression state of the response.
  //
  // This specifies whether the response bytes were compressed when they were
  // received across the wire and whether callers will receive compressed or
  // uncompressed bytes when they listen to the response body byte stream.
  set compressionState(HttpClientResponseCompressionState value) {
    _checkAndUpdate();
    _data['compressionState'] = value.name;
  }

  // The reason phrase associated with the response e.g. "OK".
  set reasonPhrase(String? value) {
    _checkAndUpdate();
    if (value == null) {
      _data.remove('reasonPhrase');
    } else {
      _data['reasonPhrase'] = value;
    }
  }

  /// Whether the status code was one of the normal redirect codes.
  set isRedirect(bool value) {
    _checkAndUpdate();
    _data['isRedirect'] = value;
  }

  /// The persistent connection state returned by the server.
  set persistentConnection(bool value) {
    _checkAndUpdate();
    _data['persistentConnection'] = value;
  }

  /// The content length of the response body, in bytes.
  set contentLength(int? value) {
    _checkAndUpdate();
    if (value == null) {
      _data.remove('contentLength');
    } else {
      _data['contentLength'] = value;
    }
  }

  set statusCode(int value) {
    _checkAndUpdate();
    _data['statusCode'] = value;
  }

  /// The time at which the initial response was received.
  set startTime(DateTime value) {
    _checkAndUpdate();
    _data['startTime'] = value.microsecondsSinceEpoch;
  }

  HttpProfileResponseData._(
    this._data,
    this._updated,
  ) {
    _data['redirects'] = <Map<String, dynamic>>[];
  }

  void _checkAndUpdate() {
    if (_isClosed) {
      throw StateError('HttpProfileResponseData has been closed, no further '
          'updates are allowed');
    }
    _updated();
  }

  /// Signal that the response, including the entire response body, has been
  /// received.
  ///
  /// [bodySink] will be closed and the fields of [HttpProfileResponseData] will
  /// no longer be changeable.
  ///
  /// [endTime] is the time when the response was fully received. It defaults
  /// to the current time.
  void close([DateTime? endTime]) {
    _checkAndUpdate();
    _isClosed = true;
    bodySink.close();
    _data['endTime'] = (endTime ?? DateTime.now()).microsecondsSinceEpoch;
  }

  /// Signal that receiving the response has failed with an error.
  ///
  /// [bodySink] will be closed and the fields of [HttpProfileResponseData] will
  /// no longer be changeable.
  ///
  /// [value] is a textual description of the error e.g. 'host does not exist'.
  ///
  /// [endTime] is the time when the error occurred. It defaults to the current
  /// time.
  void closeWithError(String value, [DateTime? endTime]) {
    _checkAndUpdate();
    _isClosed = true;
    bodySink.close();
    _data['error'] = value;
    _data['endTime'] = (endTime ?? DateTime.now()).microsecondsSinceEpoch;
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
  /// profile.addEvent(
  ///   HttpProfileRequestEvent(
  ///     timestamp: DateTime.now(),
  ///     name: "Connection Established",
  ///   ),
  /// );
  /// profile.addEvent(
  ///   HttpProfileRequestEvent(
  ///     timestamp: DateTime.now(),
  ///     name: "Remote Disconnected",
  ///   ),
  /// );
  /// ```
  void addEvent(HttpProfileRequestEvent event) {
    (_data['events'] as List<Map<String, dynamic>>).add(event._toJson());
    _updated();
  }

  /// Details about the request.
  late final HttpProfileRequestData requestData;

  /// Details about the response.
  late final HttpProfileResponseData responseData;

  void _updated() =>
      _data['_lastUpdateTime'] = DateTime.now().microsecondsSinceEpoch;

  HttpClientRequestProfile._({
    required DateTime requestStartTime,
    required String requestMethod,
    required String requestUri,
  }) {
    _data['isolateId'] = Service.getIsolateId(Isolate.current)!;
    _data['requestStartTimestamp'] = requestStartTime.microsecondsSinceEpoch;
    _data['requestMethod'] = requestMethod;
    _data['requestUri'] = requestUri;
    _data['events'] = <Map<String, dynamic>>[];
    _data['requestData'] = <String, dynamic>{};
    requestData = HttpProfileRequestData._(_data, _updated);
    _data['responseData'] = <String, dynamic>{};
    responseData = HttpProfileResponseData._(
        _data['responseData'] as Map<String, dynamic>, _updated);
    _data['_requestBodyStream'] = requestData._body.stream;
    _data['_responseBodyStream'] = responseData._body.stream;
    // This entry is needed to support the updatedSince parameter of
    // ext.dart.io.getHttpProfile.
    _updated();
  }

  /// If HTTP profiling is enabled, returns an [HttpClientRequestProfile],
  /// otherwise returns `null`.
  static HttpClientRequestProfile? profile({
    /// The time at which the request was initiated.
    required DateTime requestStartTime,

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
      requestStartTime: requestStartTime,
      requestMethod: requestMethod,
      requestUri: requestUri,
    );
    addHttpClientProfilingData(requestProfile._data);
    return requestProfile;
  }
}
