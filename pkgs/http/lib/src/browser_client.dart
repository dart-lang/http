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
        ReadableStreamReadResult,
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
        _bodyToStream(request, response),
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

Object _toClientException(Object e, BaseRequest request) {
  if (e case DOMException(name: 'AbortError')) {
    return RequestAbortedException(request.url);
  }
  if (e is! ClientException) {
    var message = e.toString();
    if (message.startsWith('TypeError: ')) {
      message = message.substring('TypeError: '.length);
    }
    e = ClientException(message, request.url);
  }
  return e;
}

Never _rethrowAsClientException(Object e, StackTrace st, BaseRequest request) {
  Error.throwWithStackTrace(_toClientException(e, request), st);
}

Stream<List<int>> _bodyToStream(BaseRequest request, Response response) =>
    Stream.multi(
      isBroadcast: false,
      (listener) => _readStreamBody(request, response, listener),
    );

Future<void> _readStreamBody(BaseRequest request, Response response,
    MultiStreamController<List<int>> controller) async {
  final reader = response.body?.getReader() as ReadableStreamDefaultReader?;
  if (reader == null) {
    // No response? Treat that as an empty stream.
    await controller.close();
    return;
  }

  Completer<void>? resumeSignal;
  var cancelled = false;
  var hadError = false;
  controller
    ..onResume = () {
      if (resumeSignal case final resume?) {
        resumeSignal = null;
        resume.complete();
      }
    }
    ..onCancel = () async {
      try {
        cancelled = true;
        // We only cancel the reader when the subscription is cancelled - we
        // don't need to do that for normal done events because the stream is in
        // a completed state at that point.
        await reader.cancel().toDart;
      } catch (e, s) {
        // It is possible for reader.cancel() to throw. This happens either
        // because the stream has already been in an error state (in which case
        // we would have called addErrorSync() before and don't need to re-
        // report the error here), or because of an issue here (MDN says the
        // method can throw if "The source object is not a
        // ReadableStreamDefaultReader, or the stream has no owner."). Both of
        // these don't look applicable here, but we want to ensure a new error
        // in cancel() is surfaced to the caller.
        if (!hadError) {
          _rethrowAsClientException(e, s, request);
        }
      }
    };

  // Async loop reading chunks from `bodyStreamReader` and sending them to
  // `controller`.
  // Checks for pause/cancel after delivering each event.
  // Exits if stream closes or becomes an error, or if cancelled.
  while (true) {
    final ReadableStreamReadResult chunk;
    try {
      chunk = await reader.read().toDart;
    } catch (e, s) {
      // After a stream was cancelled, adding error events would result in
      // unhandled async errors. This is most likely an AbortError anyway, so
      // not really an exceptional state. We report errors of .cancel() in
      // onCancel, that should cover this case.
      if (!cancelled) {
        hadError = true;
        controller.addErrorSync(_toClientException(e, request), s);
        await controller.close();
      }

      break;
    }

    if (chunk.done) {
      // Sync because we're forwarding an async event.
      controller.closeSync();
      break;
    } else {
      // Handle chunk whether paused, cancelled or not.
      // If subscription is cancelled, it's a no-op to add events.
      // If subscription is paused, events will be buffered until resumed,
      // which is what we need.
      // We can use addSync here because we're only forwarding this async
      // event.
      controller.addSync((chunk.value! as JSUint8Array).toDart);
    }

    // Check pause/cancel state immediately *after* delivering event,
    // listener might have paused or cancelled.
    if (controller.isPaused) {
      // Will never complete if cancelled before resumed.
      await (resumeSignal ??= Completer<void>()).future;
    }
    if (!controller.hasListener) break; // Is cancelled.
  }
}

/// Workaround for `Headers` not providing a way to iterate the headers.
@JS()
extension type _IterableHeaders._(JSObject _) implements JSObject {
  external void forEach(JSFunction fn);
}
