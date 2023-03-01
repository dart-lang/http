// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'streamed_response.dart';

/// An HTTP response where the response body is received asynchronously after
/// the headers have been received.
class IOStreamedResponse extends StreamedResponse {
  final HttpClientResponse? _inner;

  /// Creates a new streaming response.
  ///
  /// [stream] should be a single-subscription stream.
  ///
  /// If [inner] is not provided, [detachSocket] will throw.
  IOStreamedResponse(super.stream, super.statusCode,
      {super.contentLength,
      super.request,
      super.headers,
      super.isRedirect,
      super.persistentConnection,
      super.reasonPhrase,
      HttpClientResponse? inner})
      : _inner = inner;

  /// Detaches the underlying socket from the HTTP server.
  ///
  /// Will throw if `inner` was not set or `null` when `this` was created.
  Future<Socket> detachSocket() async => _inner!.detachSocket();
}
