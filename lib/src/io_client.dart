// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import '../http.dart' show ByteStream;
import 'base_client.dart';
import 'base_request.dart';
import 'exception.dart';
import 'io_streamed_response.dart';

/// Create an [IOClient].
///
/// Used from conditional imports, matches the definition in `client_stub.dart`.
BaseClient createClient() => IOClient();

/// A `dart:io`-based HTTP client.
class IOClient extends BaseClient {
  /// The underlying `dart:io` HTTP client.
  HttpClient? _inner;

  IOClient([HttpClient? inner]) : _inner = inner ?? HttpClient();

  /// Sends an HTTP request and asynchronously returns the response.
  @override
  Future<IOStreamedResponse> send(BaseRequest request,
      {void Function(int total, int loaded)? onUploadProgress}) async {
    if (_inner == null) {
      throw ClientException(
          'HTTP request failed. Client is already closed.', request.url);
    }

    var stream = request.finalize();
    ByteStream? _stream2;

    var contentLength = request.contentLength;
    if (onUploadProgress != null && contentLength != null) {
      var load = 0;
      _stream2 =
          ByteStream(stream.transform(StreamTransformer.fromBind((d) async* {
        await for (var data in d) {
          load += data.length;
          onUploadProgress(contentLength, load);
          yield data;
        }
      })));
    }

    try {
      var ioRequest = (await _inner!.openUrl(request.method, request.url))
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..contentLength = (contentLength ?? -1)
        ..persistentConnection = request.persistentConnection;
      request.headers.forEach((name, value) {
        ioRequest.headers.set(name, value);
      });

      var response =
          await (_stream2 ?? stream).pipe(ioRequest) as HttpClientResponse;

      var headers = <String, String>{};
      response.headers.forEach((key, values) {
        headers[key] = values.join(',');
      });

      return IOStreamedResponse(
          response.handleError((Object error) {
            final httpException = error as HttpException;
            throw ClientException(httpException.message, httpException.uri);
          }, test: (error) => error is HttpException),
          response.statusCode,
          contentLength:
              response.contentLength == -1 ? null : response.contentLength,
          request: request,
          headers: headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
          inner: response);
    } on HttpException catch (error) {
      throw ClientException(error.message, error.uri);
    }
  }

  /// Closes the client.
  ///
  /// Terminates all active connections. If a client remains unclosed, the Dart
  /// process may not terminate.
  @override
  void close() {
    if (_inner != null) {
      _inner!.close(force: true);
      _inner = null;
    }
  }
}
