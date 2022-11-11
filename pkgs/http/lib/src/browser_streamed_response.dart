// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

import 'base_request.dart';
import 'streamed_response.dart';

/// An HTTP response where the response body is received asynchronously after
/// the headers have been received.
class BrowserStreamedResponse extends StreamedResponse {
  final HttpRequest? _inner;

  /// Creates a new streaming response.
  ///
  /// [stream] should be a single-subscription stream.
  BrowserStreamedResponse(Stream<List<int>> stream, int statusCode,
      {int? contentLength,
      BaseRequest? request,
      Map<String, String> headers = const {},
      bool isRedirect = false,
      bool persistentConnection = true,
      String? reasonPhrase,
      HttpRequest? inner})
      : _inner = inner,
        super(stream, statusCode,
            contentLength: contentLength,
            request: request,
            headers: headers,
            isRedirect: isRedirect,
            persistentConnection: persistentConnection,
            reasonPhrase: reasonPhrase);

  /// Closes the underlying HTTP Request
  ///
  /// Will throw if `inner` was not set or `null` when `this` was created.
  @override
  Future<void> close() async {
    _inner!.abort();
  }
}
