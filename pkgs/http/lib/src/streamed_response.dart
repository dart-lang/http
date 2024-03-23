// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'base_response.dart';
import 'byte_stream.dart';
import 'utils.dart';

/// An HTTP response where the response body is received asynchronously after
/// the headers have been received.
class StreamedResponse extends BaseResponse {
  /// The stream from which the response body data can be read.
  ///
  /// This should always be a single-subscription stream.
  final ByteStream stream;

  /// Creates a new streaming response.
  ///
  /// [stream] should be a single-subscription stream.
  StreamedResponse(Stream<List<int>> stream, super.statusCode,
      {super.contentLength,
      super.request,
      super.headers,
      super.isRedirect,
      super.persistentConnection,
      super.reasonPhrase})
      : stream = toByteStream(stream);
}

/// This class is private to `package:http` and will be removed when
/// `package:http` v2 is released.
class StreamedResponseV2 extends StreamedResponse
    implements BaseResponseWithUrl {
  @override
  final Uri url;

  StreamedResponseV2(super.stream, super.statusCode,
      {required this.url,
      super.contentLength,
      super.request,
      super.headers,
      super.isRedirect,
      super.persistentConnection,
      super.reasonPhrase});
}
