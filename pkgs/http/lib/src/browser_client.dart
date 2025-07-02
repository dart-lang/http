// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart'
    show
        AbortController,
        DOMException,
        HeadersInit,
        ReadableStreamDefaultReader,
        RequestInfo,
        RequestInit,
        Response;

import 'abortable.dart';
import 'base_client.dart';
import 'base_request.dart';
import 'exception.dart';
import 'streamed_response.dart';

/// Create a [BrowserClient].
///
/// Used from conditional imports, matches the definition in `client_stub.dart`.
BaseClient createClient() {
  if (const bool.fromEnvironment('no_default_http_client')) {
    throw StateError('no_default_http_client was defined but runWithClient '
        'was not used to configure a Client implementation.');
  }
  return BrowserClient();
}

@JS('fetch')
external JSPromise<Response> _fetch(
  RequestInfo input, [
  RequestInit init,
]);

/// A `package:web`-based HTTP client that runs in the browser and is backed by
/// [`window.fetch`](https://fetch.spec.whatwg.org/).
///
/// This client inherits some limitations of `window.fetch`:
///
/// - [BaseRequest.persistentConnection] is ignored;
/// - Setting [BaseRequest.followRedirects] to `false` will cause
///   [ClientException] when a redirect is encountered;
/// - The value of [BaseRequest.maxRedirects] is ignored.
///
/// Responses are streamed but requests are not. A request will only be sent
/// once all the data is available.
class BrowserClient extends BaseClient {
  /// Whether to send credentials such as cookies or authorization headers for
  /// cross-site requests.
  ///
  /// Defaults to `false`.
  bool withCredentials = false;

  bool _isClosed = false;
  final _openRequestAbortControllers = <AbortController>[];

  /// Sends an HTTP request and asynchronously returns the response.
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (_isClosed) {
      throw ClientException(
          'HTTP request failed. Client is already closed.', request.url);
    }

    final abortController = AbortController();
    _openRequestAbortControllers.add(abortController);

    final bodyBytes = await request.finalize().toBytes();
    try {
      if (request case Abortable(:final abortTrigger?)) {
        // Tear-offs of external extension type interop members are disallowed
        // ignore: unnecessary_lambdas
        unawaited(abortTrigger.whenComplete(() => abortController.abort()));
      }

      final response = await _fetch(
        '${request.url}'.toJS,
        RequestInit(
          method: request.method,
          body: bodyBytes.isNotEmpty ? bodyBytes.toJS : null,
          credentials: withCredentials ? 'include' : 'same-origin',
          headers: {
            if (request.contentLength case final contentLength?)
              'content-length': contentLength,
            for (var header in request.headers.entries)
              header.key: header.value,
          }.jsify()! as HeadersInit,
          signal: abortController.signal,
          redirect: request.followRedirects ? 'follow' : 'error',
        ),
      ).toDart;

      final contentLengthHeader = response.headers.get('content-length');

      final contentLength = contentLengthHeader != null
          ? int.tryParse(contentLengthHeader)
          : null;

      if (contentLength == null && contentLengthHeader != null) {
        throw ClientException(
          'Invalid content-length header [$contentLengthHeader].',
          request.url,
        );
      }

      final headers = <String, String>{};
      (response.headers as _IterableHeaders)
          .forEach((String value, String header, [JSAny? _]) {
        headers[header.toLowerCase()] = value;
      }.toJS);

      return StreamedResponseV2(
        _readBody(request, response),
        response.status,
        headers: headers,
        request: request,
        contentLength: contentLength,
        url: Uri.parse(response.url),
        reasonPhrase: response.statusText,
      );
    } catch (e, st) {
      _rethrowAsClientException(e, st, request);
    } finally {
      _openRequestAbortControllers.remove(abortController);
    }
  }

  /// Closes the client.
  ///
  /// This terminates all active requests, which may cause them to throw
  /// [RequestAbortedException] or [ClientException].
  @override
  void close() {
    for (final abortController in _openRequestAbortControllers) {
      abortController.abort();
    }
    _isClosed = true;
  }
}

Never _rethrowAsClientException(Object e, StackTrace st, BaseRequest request) {
  if (e case DOMException(:final name) when name == 'AbortError') {
    Error.throwWithStackTrace(RequestAbortedException(request.url), st);
  }
  if (e is! ClientException) {
    var message = e.toString();
    if (message.startsWith('TypeError: ')) {
      message = message.substring('TypeError: '.length);
    }
    e = ClientException(message, request.url);
  }
  Error.throwWithStackTrace(e, st);
}

Stream<List<int>> _readBody(BaseRequest request, Response response) async* {
  final bodyStreamReader =
      response.body?.getReader() as ReadableStreamDefaultReader?;

  if (bodyStreamReader == null) {
    return;
  }

  var isDone = false, isError = false;
  try {
    while (true) {
      final chunk = await bodyStreamReader.read().toDart;
      if (chunk.done) {
        isDone = true;
        break;
      }
      yield (chunk.value! as JSUint8Array).toDart;
    }
  } catch (e, st) {
    isError = true;
    _rethrowAsClientException(e, st, request);
  } finally {
    if (!isDone) {
      try {
        // catchError here is a temporary workaround for
        // http://dartbug.com/57046: an exception from cancel() will
        // clobber an exception which is currently in flight.
        await bodyStreamReader
            .cancel()
            .toDart
            .catchError((_) => null, test: (_) => isError);
      } catch (e, st) {
        // If we have already encountered an error swallow the
        // error from cancel and simply let the original error to be
        // rethrown.
        if (!isError) {
          _rethrowAsClientException(e, st, request);
        }
      }
    }
  }
}

/// Workaround for `Headers` not providing a way to iterate the headers.
@JS()
extension type _IterableHeaders._(JSObject _) implements JSObject {
  external void forEach(JSFunction fn);
}
