// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'http_profile.dart';

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
    _data['headers'] = splitHeaderValues(value);
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
    unawaited(bodySink.close());
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
    unawaited(bodySink.close());
    _data['error'] = value;
    _data['endTime'] = (endTime ?? DateTime.now()).microsecondsSinceEpoch;
  }
}
