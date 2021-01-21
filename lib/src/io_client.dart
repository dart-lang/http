// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

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
  Future<IOStreamedResponse> send(BaseRequest request, {Duration? timeout}) {
    final completer = Completer<IOStreamedResponse>();
    _send(request, timeout, completer);
    return completer.future;
  }

  Future<void> _send(BaseRequest request, Duration? timeout,
      Completer<IOStreamedResponse> completer) async {
    var stream = request.finalize();

    Timer? timer;
    late void Function() onTimeout;
    if (timeout != null) {
      timer = Timer(timeout, () {
        onTimeout();
      });
      onTimeout = () {
        completer.completeError(TimeoutException('Request aborted', timeout));
      };
    }
    try {
      var ioRequest = (await _inner!.openUrl(request.method, request.url))
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..contentLength = (request.contentLength ?? -1)
        ..persistentConnection = request.persistentConnection;
      if (completer.isCompleted) return;
      request.headers.forEach((name, value) {
        ioRequest.headers.set(name, value);
      });

      if (timeout != null) {
        onTimeout = () {
          ioRequest.abort();
          completer.completeError(TimeoutException('Request aborted', timeout));
        };
      }

      var response = await stream.pipe(ioRequest) as HttpClientResponse;
      if (completer.isCompleted) return;

      var headers = <String, String>{};
      response.headers.forEach((key, values) {
        headers[key] = values.join(',');
      });
      var responseStream = response.handleError((error) {
        final httpException = error as HttpException;
        throw ClientException(httpException.message, httpException.uri);
      }, test: (error) => error is HttpException).transform<List<int>>(
          StreamTransformer.fromHandlers(handleDone: (sink) {
        timer?.cancel();
        sink.close();
      }));

      if (timeout != null) {
        onTimeout = () {
          // TODO, is this necessary? How will it surface?
          response.detachSocket().then((socket) => socket.destroy());
        };
      }

      completer.complete(IOStreamedResponse(responseStream, response.statusCode,
          contentLength:
              response.contentLength == -1 ? null : response.contentLength,
          request: request,
          headers: headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
          inner: response));
    } on HttpException catch (error) {
      if (completer.isCompleted) return;
      completer.completeError(ClientException(error.message, error.uri));
    } catch (error, stackTrace) {
      if (completer.isCompleted) return;
      completer.completeError(error, stackTrace);
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
