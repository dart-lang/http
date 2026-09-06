// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import '../http.dart';
import 'io_streamed_response.dart';

/// Create an [IOClient].
///
/// Used from conditional imports, matches the definition in `client_stub.dart`.
BaseClient createClient() {
  if (const bool.fromEnvironment('no_default_http_client')) {
    throw StateError('no_default_http_client was defined but runWithClient '
        'was not used to configure a Client implementation.');
  }
  return IOClient();
}

/// Exception thrown when the underlying [HttpClient] throws a
/// [SocketException].
///
/// Implements [SocketException] to avoid breaking existing users of
/// [IOClient] that may catch that exception.
class _ClientSocketException extends ClientException
    implements SocketException {
  final SocketException cause;
  _ClientSocketException(SocketException e, Uri uri)
      : cause = e,
        super(e.message, uri);

  @override
  InternetAddress? get address => cause.address;

  @override
  OSError? get osError => cause.osError;

  @override
  int? get port => cause.port;

  @override
  String toString() => 'ClientException with $cause, uri=$uri';
}

class _IOStreamedResponseV2 extends IOStreamedResponse
    implements BaseResponseWithUrl {
  @override
  final Uri url;

  _IOStreamedResponseV2(super.stream, super.statusCode,
      {required this.url,
      super.contentLength,
      super.request,
      super.headers,
      super.isRedirect,
      super.persistentConnection,
      super.reasonPhrase,
      super.inner});
}

/// A `dart:io`-based HTTP [Client].
///
/// If there is a socket-level failure when communicating with the server
/// (for example, if the server could not be reached), [IOClient] will emit a
/// [ClientException] that also implements [SocketException]. This allows
/// callers to get more detailed exception information for socket-level
/// failures, if desired.
///
/// For example:
/// ```dart
/// final client = http.Client();
/// late String data;
/// try {
///   data = await client.read(Uri.https('example.com', ''));
/// } on SocketException catch (e) {
///   // Exception is transport-related, check `e.osError` for more details.
/// } on http.ClientException catch (e) {
///   // Exception is HTTP-related (e.g. the server returned a 404 status code).
///   // If the handler for `SocketException` were removed then all exceptions
///   // would be caught by this handler.
/// }
/// ```
class IOClient extends BaseClient {
  /// The underlying `dart:io` HTTP client.
  HttpClient? _inner;

  /// Create a new `dart:io`-based HTTP [Client].
  ///
  /// If [inner] is provided then it can be used to provide configuration
  /// options for the client.
  ///
  /// For example:
  /// ```dart
  /// final httpClient = HttpClient()
  ///    ..userAgent = 'Book Agent'
  ///    ..idleTimeout = const Duration(seconds: 5);
  /// final client = IOClient(httpClient);
  /// ```
  IOClient([HttpClient? inner]) : _inner = inner ?? HttpClient();

  /// Sends an HTTP request and asynchronously returns the response.
  @override
  Future<IOStreamedResponse> send(BaseRequest request) async {
    if (_inner == null) {
      throw ClientException(
          'HTTP request failed. Client is already closed.', request.url);
    }

    var stream = request.finalize();

    try {
      var ioRequest = (await _inner!.openUrl(request.method, request.url))
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..contentLength = (request.contentLength ?? -1)
        ..persistentConnection = request.persistentConnection;
      request.headers.forEach((name, value) {
        ioRequest.headers.set(name, value, preserveHeaderCase: true);
      });

      // SDK request aborting is only effective up until the request is
      // closed, at which point the full response always becomes available.
      // This happens at `pipe`, which closes the request once the request
      // stream is pumped in.
      //
      // Abort is therefore handled in two phases, split on the `pipe` boundary:
      //
      //  * Before we have a response: use SDK abort, which makes `pipe` (and so
      //    this method) throw the aborted error.
      //
      //  * After we have a response, WE own the `HttpClientResponse` and must
      //    release it ourselves; otherwise the connection stays open
      //    waiting for a body that will never be read.
      //    One handler covers all three cases:
      //      - Never listened to: cancel the native response to destroy the
      //        connection.
      //      - Streaming: inject the aborted error into the wrapper and cancel
      //        the active subscription, which destroys the connection.
      //      - Already fully read: nothing to release, so it's a no-op.

      var isAborted = false;
      var hasResponse = false;

      if (request case Abortable(:final abortTrigger?)) {
        unawaited(
          abortTrigger.whenComplete(() {
            isAborted = true;
            if (!hasResponse) {
              ioRequest.abort(RequestAbortedException(request.url));
            }
          }),
        );
      }

      final response = await stream.pipe(ioRequest) as HttpClientResponse;
      hasResponse = true;

      StreamSubscription<List<int>>? ioResponseSubscription;
      late final StreamController<List<int>> responseController;
      var responseListenStarted = false;

      void abortResponse() {
        if (!responseController.isClosed) {
          responseController
            ..addError(RequestAbortedException(request.url))
            ..close();
        }
        if (responseListenStarted) {
          unawaited(ioResponseSubscription?.cancel());
        } else {
          unawaited(response.listen(null, onError: (_, __) {}).cancel());
        }
      }

      responseController = StreamController(
        onListen: () {
          if (isAborted) return;
          responseListenStarted = true;
          ioResponseSubscription = response.listen(
            responseController.add,
            onDone: () {
              // `responseController.close` will trigger the `onCancel`
              // callback. Assign `ioResponseSubscription` to `null` to avoid
              // calling its `cancel` method.
              ioResponseSubscription = null;
              unawaited(responseController.close());
            },
            onError: (Object err, StackTrace stackTrace) {
              if (err is HttpException) {
                responseController.addError(
                  ClientException(err.message, err.uri),
                  stackTrace,
                );
              } else {
                responseController.addError(err, stackTrace);
              }
            },
          );
        },
        onPause: () => ioResponseSubscription?.pause(),
        onResume: () => ioResponseSubscription?.resume(),
        onCancel: () => ioResponseSubscription?.cancel(),
        sync: true,
      );

      if (request case Abortable(:final abortTrigger?)) {
        unawaited(abortTrigger.whenComplete(abortResponse));
      }

      var headers = <String, String>{};
      response.headers.forEach((key, values) {
        // TODO: Remove trimRight() when
        // https://github.com/dart-lang/sdk/issues/53005 is resolved and the
        // package:http SDK constraint requires that version or later.
        headers[key] = values.map((value) => value.trimRight()).join(',');
      });

      return _IOStreamedResponseV2(
        responseController.stream,
        response.statusCode,
        contentLength:
            response.contentLength == -1 ? null : response.contentLength,
        request: request,
        headers: headers,
        isRedirect: response.isRedirect,
        url: response.redirects.isNotEmpty
            ? response.redirects.last.location
            : request.url,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
        inner: response,
      );
    } on SocketException catch (error) {
      throw _ClientSocketException(error, request.url);
    } on HttpException catch (error) {
      throw ClientException(error.message, error.uri);
    }
  }

  @override
  void close() {
    if (_inner != null) {
      _inner!.close(force: true);
      _inner = null;
    }
  }
}
