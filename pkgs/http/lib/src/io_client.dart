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
        ioRequest.headers.set(name, value);
      });

      // SDK request aborting is only effective up until the request is closed,
      // at which point the full response always becomes available.
      // This occurs at `pipe`, which automatically closes the request once the
      // request stream has been pumped in.
      //
      // Therefore, we have multiple strategies:
      //  * If the user aborts before we have a response, we can use SDK abort,
      //    which causes the `pipe` (and therefore this method) to throw the
      //    aborted error
      //  * If the user aborts after we have a response but before they listen
      //    to it, we immediately emit the aborted error then close the response
      //    as soon as they listen to it
      //  * If the user aborts whilst streaming the response, we inject the
      //    aborted error, then close the response

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
      responseController = StreamController(
        onListen: () {
          if (isAborted) {
            responseController
              ..addError(RequestAbortedException(request.url))
              ..close();
            return;
          } else if (request case Abortable(:final abortTrigger?)) {
            abortTrigger.whenComplete(() {
              if (!responseController.isClosed) {
                responseController
                  ..addError(RequestAbortedException(request.url))
                  ..close();
              }
              ioResponseSubscription?.cancel();
            });
          }

          ioResponseSubscription = response.listen(
            responseController.add,
            onDone: () {
              // `reponseController.close` will trigger the `onCancel` callback.
              // Assign `ioResponseSubscription` to `null` to avoid calling its
              // `cancel` method.
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

  /// Closes the client.
  ///
  /// Terminates all active connections. If a client remains unclosed, the Dart
  /// process may not terminate.
  ///
  /// The behavior of `close` is not defined if there are requests executing
  /// when `close` is called.
  @override
  void close() {
    if (_inner != null) {
      _inner!.close(force: true);
      _inner = null;
    }
  }
}
