// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'http_profile.dart';

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
    _requestData['headers'] = splitHeaderValues(value);
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
    unawaited(bodySink.close());
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
    unawaited(bodySink.close());
    _requestData['error'] = value;
    _data['requestEndTimestamp'] =
        (endTime ?? DateTime.now()).microsecondsSinceEpoch;
  }
}
