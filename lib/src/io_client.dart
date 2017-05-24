// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';

import 'base_client.dart';
import 'exception.dart';
import 'request.dart';
import 'response.dart';

/// A `dart:io`-based HTTP client.
///
/// This is the default client when running on the command line.
class IOClient extends BaseClient {
  /// The underlying `dart:io` HTTP client.
  HttpClient _inner;

  /// Creates a new HTTP client.
  IOClient([HttpClient inner]) : _inner = inner ?? new HttpClient();

  /// Sends an HTTP request and asynchronously returns the response.
  Future<Response> send(Request request) async {
    var stream = await request.read();

    try {
      var ioRequest = await _inner.openUrl(request.method, request.url);
      var context = request.context;

      ioRequest
          ..followRedirects = context['io.followRedirects'] ?? true
          ..maxRedirects = context['io.maxRedirects'] ?? 5
          ..contentLength = request.contentLength == null
              ? -1
              : request.contentLength
          ..persistentConnection = context['io.persistentConnection'] ?? true;
      request.headers.forEach((name, value) {
        ioRequest.headers.set(name, value);
      });

      var response = await stream.pipe(
          DelegatingStreamConsumer.typed<List<int>>(ioRequest)
      ) as HttpClientResponse;

      var headers = <String, String>{};
      response.headers.forEach((key, values) {
        headers[key] = values.join(',');
      });

      return new Response(
          _responseUrl(request, response),
          response.statusCode,
          reasonPhrase: response.reasonPhrase,
          body: DelegatingStream.typed<List<int>>(response).handleError(
              (error) => throw new ClientException(error.message, error.uri),
              test: (error) => error is HttpException),
          headers: headers,
          context: context);
    } on HttpException catch (error) {
      throw new ClientException(error.message, error.uri);
    } on SocketException catch (error) {
      throw new ClientException(error.message, request.url);
    }
  }

  /// Closes the client. This terminates all active connections. If a client
  /// remains unclosed, the Dart process may not terminate.
  void close() {
    if (_inner != null) _inner.close(force: true);
    _inner = null;
  }
}

Uri _responseUrl(Request request, HttpClientResponse response) {
  var redirects = response.redirects;

  if (redirects.isEmpty) {
    return request.url;
  }

  var location = redirects.last.location;

  // Redirect can be relative or absolute
  return (location.isAbsolute) ? location : request.url.resolveUri(location);
}
