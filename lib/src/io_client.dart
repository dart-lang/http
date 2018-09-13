// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';

import 'base_client.dart';
import 'base_request.dart';
import 'exception.dart';
import 'streamed_response.dart';

/// Used from conditional imports, matches the definition in `client_stub.dart`.
BaseClient createClient() => IOClient();

/// A `dart:io`-based HTTP client.
///
/// This is the default client when running on the command line.
class IOClient extends BaseClient {
  /// The underlying `dart:io` HTTP client.
  HttpClient _inner;

  /// Creates a new HTTP client.
  IOClient([HttpClient inner]) : _inner = inner ?? new HttpClient();

  /// Sends an HTTP request and asynchronously returns the response.
  Future<StreamedResponse> send(BaseRequest request) async {
    var stream = request.finalize();

    try {
      var ioRequest = await _inner.openUrl(request.method, request.url);

      ioRequest
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..contentLength =
            request.contentLength == null ? -1 : request.contentLength
        ..persistentConnection = request.persistentConnection;
      request.headers.forEach((name, value) {
        ioRequest.headers.set(name, value);
      });

      var response =
          await stream.pipe(DelegatingStreamConsumer.typed(ioRequest));
      var headers = <String, String>{};
      response.headers.forEach((key, values) {
        headers[key] = values.join(',');
      });

      return new StreamedResponse(
          DelegatingStream.typed<List<int>>(response).handleError(
              (error) => throw new ClientException(error.message, error.uri),
              test: (error) => error is HttpException),
          response.statusCode,
          contentLength:
              response.contentLength == -1 ? null : response.contentLength,
          request: request,
          headers: headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase);
    } on HttpException catch (error) {
      throw new ClientException(error.message, error.uri);
    }
  }

  /// Closes the client. This terminates all active connections. If a client
  /// remains unclosed, the Dart process may not terminate.
  void close() {
    if (_inner != null) _inner.close(force: true);
    _inner = null;
  }
}
