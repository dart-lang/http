// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html';
import 'dart:typed_data';

import 'package:stack_trace/stack_trace.dart';

import 'src/base_client.dart';
import 'src/byte_stream.dart';
import 'src/exception.dart';
import 'src/request.dart';
import 'src/response.dart';

// TODO(nweiz): Move this under src/, re-export from lib/http.dart, and use this
// automatically from [new Client] once sdk#24581 is fixed.

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
  final _xhrs = new Set<HttpRequest>();

  /// Creates a new HTTP client.
  BrowserClient();

  /// Sends an HTTP request and asynchronously returns the response.
  Future<Response> send(Request request) async {
    var stream = new ByteStream(request.read());
    var bytes = await stream.toBytes();
    var xhr = new HttpRequest();
    _xhrs.add(xhr);
    _openHttpRequest(xhr, request.method, request.url.toString(), asynch: true);
    xhr.responseType = 'blob';
    xhr.withCredentials = request.context['html.withCredentials'] ?? false;
    request.headers.forEach(xhr.setRequestHeader);

    var completer = new Completer<Response>();
    xhr.onLoad.first.then((_) {
      // TODO(nweiz): Set the response type to "arraybuffer" when issue 18542
      // is fixed.
      var blob = xhr.response == null ? new Blob([]) : xhr.response;
      var reader = new FileReader();

      reader.onLoad.first.then((_) {
        var body = reader.result as Uint8List;
        completer.complete(new Response(
            xhr.responseUrl,
            xhr.status,
            reasonPhrase: xhr.statusText,
            body: new ByteStream.fromBytes(body),
            headers: xhr.responseHeaders));
      });

      reader.onError.first.then((error) {
        completer.completeError(
            new ClientException(error.toString(), request.url),
            new Chain.current());
      });

      reader.readAsArrayBuffer(blob);
    });

    xhr.onError.first.then((_) {
      // Unfortunately, the underlying XMLHttpRequest API doesn't expose any
      // specific information about the error itself.
      completer.completeError(
          new ClientException("XMLHttpRequest error.", request.url),
          new Chain.current());
    });

    xhr.send(bytes);

    try {
      return await completer.future;
    } finally {
      _xhrs.remove(xhr);
    }
  }

  // TODO(nweiz): Remove this when sdk#24637 is fixed.
  void _openHttpRequest(HttpRequest request, String method, String url,
      {bool asynch, String user, String password}) {
    request.open(method, url, async: asynch, user: user, password: password);
  }

  /// Closes the client.
  ///
  /// This terminates all active requests.
  void close() {
    for (var xhr in _xhrs) {
      xhr.abort();
    }
  }
}
