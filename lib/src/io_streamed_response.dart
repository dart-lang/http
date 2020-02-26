// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'base_request.dart';
import 'streamed_response.dart';

/// An HTTP response where the response body is received asynchronously after
/// the headers have been received.
class IOStreamedResponse extends StreamedResponse {
  HttpClientResponse _inner;

  /// Creates a new streaming response.
  ///
  /// [stream] should be a single-subscription stream.
  IOStreamedResponse(Stream<List<int>> stream, int statusCode,
      {int contentLength,
      BaseRequest request,
      Map<String, String> headers = const {},
      bool isRedirect = false,
      bool persistentConnection = true,
      String reasonPhrase,
      HttpClientResponse inner})
      : super(stream, statusCode,
            contentLength: contentLength,
            request: request,
            headers: headers,
            isRedirect: isRedirect,
            persistentConnection: persistentConnection,
            reasonPhrase: reasonPhrase) {
    _inner = inner;
  }

  /// Detaches the underlying socket from the HTTP server.
  Future<Socket> detachSocket() async {
    return await _inner.detachSocket();
  }
}
