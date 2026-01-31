// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';

import 'base_request.dart';
import 'base_response.dart';
import 'streamed_response.dart';
import 'utils.dart';

/// An HTTP response where the entire response body is known in advance.
class Response extends BaseResponse {
  /// The bytes comprising the body of this response.
  final Uint8List bodyBytes;

  /// The body of the response as a string.
  ///
  /// This is converted from [bodyBytes] using the `charset` parameter of the
  /// `Content-Type` header field, if available. If it's unavailable or if the
  /// encoding name is unknown:
  /// - [utf8] is used when the content-type is 'application/json' (see [RFC 3629][]).
  /// - [latin1] is used in all other cases (see [RFC 2616][])
  ///
  /// [RFC 3629]: https://www.rfc-editor.org/rfc/rfc3629.
  /// [RFC 2616]: http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html
  String get body => _encodingForHeaders(headers).decode(bodyBytes);

  /// Creates a new HTTP response with a string body.
  Response(String body, int statusCode,
      {BaseRequest? request,
      Map<String, String> headers = const {},
      bool isRedirect = false,
      bool persistentConnection = true,
      String? reasonPhrase})
      : this.bytes(_encodingForHeaders(headers).encode(body), statusCode,
            request: request,
            headers: headers,
            isRedirect: isRedirect,
            persistentConnection: persistentConnection,
            reasonPhrase: reasonPhrase);

  /// Create a new HTTP response with a byte array body.
  Response.bytes(List<int> bodyBytes, super.statusCode,
      {super.request,
      super.headers,
      super.isRedirect,
      super.persistentConnection,
      super.reasonPhrase})
      : bodyBytes = toUint8List(bodyBytes),
        super(contentLength: bodyBytes.length);

  /// Creates a new HTTP response by waiting for the full body to become
  /// available from a [StreamedResponse].
  static Future<Response> fromStream(StreamedResponse response) async {
    final body = await response.stream.toBytes();
    return Response.bytes(body, response.statusCode,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase);
  }
}

/// Returns the encoding to use for a response with the given headers.
///
/// If the `Content-Type` header specifies a charset, it will use that charset.
/// If no charset is provided or the charset is unknown:
/// - Defaults to [utf8] if the `Content-Type` is `application/json`
///   (since JSON is defined to use UTF-8 by default).
/// - Otherwise, defaults to [latin1] for compatibility.
Encoding _encodingForHeaders(Map<String, String> headers) =>
    encodingForContentTypeHeader(_contentTypeForHeaders(headers));

/// Returns the [MediaType] object for the given headers' content-type.
///
/// Defaults to `application/octet-stream`.
MediaType _contentTypeForHeaders(Map<String, String> headers) {
  var contentType = headers['content-type'];
  if (contentType != null) return MediaType.parse(contentType);
  return MediaType('application', 'octet-stream');
}
