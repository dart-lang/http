// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html';
import 'dart:typed_data';

import 'base_client.dart';
import 'base_request.dart';
import 'byte_stream.dart';
import 'exception.dart';
import 'request_controller.dart';
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

/// A `dart:html`-based HTTP client that runs in the browser and is backed by
/// XMLHttpRequests.
///
/// This client inherits some of the limitations of XMLHttpRequest. It ignores
/// the [BaseRequest.contentLength], [BaseRequest.persistentConnection],
/// [BaseRequest.followRedirects], and [BaseRequest.maxRedirects] fields. It is
/// also unable to stream requests or responses; a request will only be sent and
/// a response will only be returned once all the data is available.
class BrowserClient extends BaseClient {
  /// The currently active XHRs.
  ///
  /// These are aborted if the client is closed.
  final _xhrs = <HttpRequest>{};

  /// Whether to send credentials such as cookies or authorization headers for
  /// cross-site requests.
  ///
  /// Defaults to `false`.
  bool withCredentials = false;

  bool _isClosed = false;

  /// Sends an HTTP request and asynchronously returns the response.
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (_isClosed) {
      throw ClientException(
          'HTTP request failed. Client is already closed.', request.url);
    }

    var bytes = await request.finalize().toBytes();

    var xhr = HttpRequest();

    // Life-cycle tracking is implemented using three completers and the
    // onReadyStateChange event. The three completers are:
    //
    // - connectCompleter (completes when OPENED) (initiates sendingCompleter)
    // - sendingCompleter (completes when HEADERS_RECEIVED)
    // (initiates receivingCompleter)
    // - receivingCompleter (completes when DONE)
    //
    // connectCompleter is initiated immediately and on completion initiates
    // sendingCompleter, and so on.
    //
    // Note 'initiated' is not 'initialized' - initiated refers to a timeout
    // being set on the completer, to ensure the step completes within the
    // specified timeout.
    final controller = request.controller;

    if (controller != null) {
      if (controller.hasLifecycleTimeouts) {
        // The browser client (which uses XHR) seems not to be able to work with
        // partial (streamed) requests or responses, so the receive timeout is
        // handled by the browser client itself.
        final tracker = controller.track(request, isStreaming: false);

        // Returns a completer for the given state if a timeout is specified
        // for it, otherwise returns null.
        Completer<void>? completer(RequestLifecycleState state) =>
            controller.hasTimeoutForLifecycleState(state)
                ? Completer<void>()
                : null;

        final connectCompleter = completer(RequestLifecycleState.connecting);
        final sendingCompleter = completer(RequestLifecycleState.sending);
        final receivingCompleter = completer(RequestLifecycleState.receiving);

        // Simply abort the XHR if a timeout or cancellation occurs.
        void handleCancel(_) => xhr.abort();

        // If a connect timeout is specified, initiate the connectCompleter.
        if (connectCompleter != null) {
          unawaited(tracker.trackRequestState(
            connectCompleter.future,
            state: RequestLifecycleState.connecting,
            onCancel: handleCancel,
          ));
        }

        xhr.onReadyStateChange.listen((_) {
          // If the connection is at the OPENED stage and the
          // connectCompleter has not yet been marked as completed, complete it.
          if (xhr.readyState == HttpRequest.OPENED) {
            if (connectCompleter != null) {
              connectCompleter.complete();
            }

            // Initiate the sendingCompleter if there is a timeout specified for
            // it.
            if (sendingCompleter != null) {
              unawaited(tracker.trackRequestState(
                sendingCompleter.future,
                state: RequestLifecycleState.sending,
                onCancel: handleCancel,
              ));
            }
          }

          // If the connection is at the HEADERS_RECEIVED stage and
          // the sendingCompleter has not yet been marked as completed,
          // complete it.
          if (xhr.readyState == HttpRequest.HEADERS_RECEIVED) {
            if (sendingCompleter != null) {
              sendingCompleter.complete();
            }

            // Initiate the receivingCompleter if there is a timeout specified
            // for it.
            if (receivingCompleter != null) {
              unawaited(tracker.trackRequestState(
                receivingCompleter.future,
                state: RequestLifecycleState.receiving,
                onCancel: handleCancel,
              ));
            }
          }

          // If the connection is at least at the DONE stage and the
          // receivingCompleter has not yet been marked as completed, complete
          // it.
          if (xhr.readyState == HttpRequest.DONE) {
            if (receivingCompleter != null) {
              receivingCompleter.complete();
            }
          }
        });
      }
    }

    _xhrs.add(xhr);
    xhr
      ..open(request.method, '${request.url}', async: true)
      ..responseType = 'arraybuffer'
      ..withCredentials = withCredentials;
    request.headers.forEach(xhr.setRequestHeader);

    var completer = Completer<StreamedResponse>();

    unawaited(xhr.onLoad.first.then((_) {
      var body = (xhr.response as ByteBuffer).asUint8List();
      completer.complete(StreamedResponse(
          ByteStream.fromBytes(body), xhr.status!,
          contentLength: body.length,
          request: request,
          headers: xhr.responseHeaders,
          reasonPhrase: xhr.statusText));
    }));

    unawaited(xhr.onError.first.then((_) {
      // Unfortunately, the underlying XMLHttpRequest API doesn't expose any
      // specific information about the error itself.
      completer.completeError(
          ClientException('XMLHttpRequest error.', request.url),
          StackTrace.current);
    }));

    xhr.send(bytes);

    try {
      return await completer.future;
    } finally {
      _xhrs.remove(xhr);
    }
  }

  /// Closes the client.
  ///
  /// This terminates all active requests.
  @override
  void close({bool force = true}) {
    _isClosed = true;

    // If the close is forced (default) then abort all pending requests.
    if (force) {
      for (var xhr in _xhrs) {
        xhr.abort();
      }
    }

    _xhrs.clear();
  }
}
