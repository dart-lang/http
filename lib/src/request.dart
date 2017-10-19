// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:math';

import 'message.dart';
import 'multipart_file.dart';
import 'multipart_body.dart';
import 'utils.dart';

/// Represents an HTTP request to be sent to a server.
class Request extends Message {
  /// The HTTP method of the request.
  ///
  /// Most commonly "GET" or "POST", less commonly "HEAD", "PUT", or "DELETE".
  /// Non-standard method names are also supported.
  final String method;

  /// The URL to which the request will be sent.
  final Uri url;

  /// Creates a new [Request] for [url], which can be a [Uri] or a [String],
  /// using [method].
  ///
  /// [body] is the request body. It may be either a [String], a [List<int>], a
  /// [Stream<List<int>>], or `null` to indicate no body. If it's a [String],
  /// [encoding] is used to encode it to a [Stream<List<int>>]. It defaults to
  /// UTF-8.
  ///
  /// [headers] are the HTTP headers for the request. If [headers] is `null`,
  /// it is treated as empty.
  ///
  /// Extra [context] can be used to pass information between inner middleware
  /// and handlers.
  Request(String method, url,
      {body,
      Encoding encoding,
      Map<String, String> headers,
      Map<String, Object> context})
      : this._(method, getUrl(url), body, encoding, headers, context);

  /// Creates a new HEAD [Request] to [url], which can be a [Uri] or a [String].
  ///
  /// [headers] are the HTTP headers for the request. If [headers] is `null`,
  /// it is treated as empty.
  ///
  /// Extra [context] can be used to pass information between inner middleware
  /// and handlers.
  Request.head(url,
      {Map<String, String> headers, Map<String, Object> context})
      : this('HEAD', url, headers: headers, context: context);

  /// Creates a new GET [Request] to [url], which can be a [Uri] or a [String].
  ///
  /// [headers] are the HTTP headers for the request. If [headers] is `null`,
  /// it is treated as empty.
  ///
  /// Extra [context] can be used to pass information between inner middleware
  /// and handlers.
  Request.get(url,
      {Map<String, String> headers, Map<String, Object> context})
      : this('GET', url, headers: headers, context: context);

  /// Creates a new POST [Request] to [url], which can be a [Uri] or a [String].
  ///
  /// [body] is the request body. It may be either a [String], a [List<int>], a
  /// [Stream<List<int>>], or `null` to indicate no body. If it's a [String],
  /// [encoding] is used to encode it to a [Stream<List<int>>]. It defaults to
  /// UTF-8.
  ///
  /// [headers] are the HTTP headers for the request. If [headers] is `null`,
  /// it is treated as empty.
  ///
  /// Extra [context] can be used to pass information between inner middleware
  /// and handlers.
  Request.post(url, body,
      {Encoding encoding,
      Map<String, String> headers,
      Map<String, Object> context})
      : this('POST', url,
      body: body, encoding: encoding, headers: headers, context: context);

  /// Creates a new PUT [Request] to [url], which can be a [Uri] or a [String].
  ///
  /// [body] is the request body. It may be either a [String], a [List<int>], a
  /// [Stream<List<int>>], or `null` to indicate no body. If it's a [String],
  /// [encoding] is used to encode it to a [Stream<List<int>>]. It defaults to
  /// UTF-8.
  ///
  /// [headers] are the HTTP headers for the request. If [headers] is `null`,
  /// it is treated as empty.
  ///
  /// Extra [context] can be used to pass information between inner middleware
  /// and handlers.
  Request.put(url, body,
      {Encoding encoding,
      Map<String, String> headers,
      Map<String, Object> context})
      : this('PUT', url,
      body: body, encoding: encoding, headers: headers, context: context);

  /// Creates a new PATCH [Request] to [url], which can be a [Uri] or a
  /// [String].
  ///
  /// [body] is the request body. It may be either a [String], a [List<int>], a
  /// [Stream<List<int>>], or `null` to indicate no body. If it's a [String],
  /// [encoding] is used to encode it to a [Stream<List<int>>]. It defaults to
  /// UTF-8.
  ///
  /// [headers] are the HTTP headers for the request. If [headers] is `null`,
  /// it is treated as empty.
  ///
  /// Extra [context] can be used to pass information between inner middleware
  /// and handlers.
  Request.patch(url, body,
      {Encoding encoding,
      Map<String, String> headers,
      Map<String, Object> context})
      : this('PATCH', url,
      body: body, encoding: encoding, headers: headers, context: context);

  /// Creates a new DELETE [Request] to [url], which can be a [Uri] or a
  /// [String].
  ///
  /// [headers] are the HTTP headers for the request. If [headers] is `null`,
  /// it is treated as empty.
  ///
  /// Extra [context] can be used to pass information between inner middleware
  /// and handlers.
  Request.delete(url,
      {Map<String, String> headers, Map<String, Object> context})
      : this('DELETE', url, headers: headers, context: context);

  factory Request.multipart(url,
      {Map<String, String> headers,
        Map<String, Object> context,
        Map<String, String> fields,
        Iterable<MultipartFile> files}) {
    fields ??= <String, String>{};
    files ??= <MultipartFile>[];

    var boundary = _boundaryString();

    return new Request._(
        'POST',
        url,
        new MultipartBody(fields, files, boundary),
        null,
        updateMap(headers, <String, String>{
          'content-type': 'multipart/form-data; boundary=$boundary'
        }),
        context);
  }

  Request._(this.method, this.url,
      body,
      Encoding encoding,
      Map<String, String> headers,
      Map<String, Object> context)
      : super(body, encoding: encoding, headers: headers, context: context);

  /// Creates a new [Request] by copying existing values and applying specified
  /// changes.
  ///
  /// New key-value pairs in [context] and [headers] will be added to the copied
  /// [Request]. If [context] or [headers] includes a key that already exists,
  /// the key-value pair will replace the corresponding entry in the copied
  /// [Request]. All other context and header values from the [Request] will be
  /// included in the copied [Request] unchanged.
  ///
  /// [body] is the request body. It may be either a [String], a [List<int>], a
  /// [Stream<List<int>>], or `null` to indicate no body.
  Request change(
      {Map<String, String> headers,
      Map<String, Object> context,
      body}) {
    var updatedHeaders = updateMap(this.headers, headers);
    var updatedContext = updateMap(this.context, context);

    return new Request._(
        this.method,
        this.url,
        body ?? getBody(this),
        this.encoding,
        updatedHeaders,
        updatedContext);
  }


  /// All character codes that are valid in multipart boundaries.
  ///
  /// This is the intersection of the characters allowed in the `bcharsnospace`
  /// production defined in [RFC 2046][] and those allowed in the `token`
  /// production defined in [RFC 1521][].
  ///
  /// [RFC 2046]: http://tools.ietf.org/html/rfc2046#section-5.1.1.
  /// [RFC 1521]: https://tools.ietf.org/html/rfc1521#section-4
  static const List<int> _boundaryCharacters = const <int>[
    43, 95, 45, 46, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57,
    65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83,
    84, 85, 86, 87, 88, 89, 90, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106,
    107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121,
    122
  ];

  /// The total length of the multipart boundaries used when building the
  /// request body.
  ///
  /// According to http://tools.ietf.org/html/rfc1341.html, this can't be longer
  /// than 70.
  static const int _boundaryLength = 70;

  static final Random _random = new Random();

  /// Returns a randomly-generated multipart boundary string
  static String _boundaryString() {
    var prefix = "dart-http-boundary-";
    var list = new List<int>.generate(_boundaryLength - prefix.length,
            (index) =>
        _boundaryCharacters[_random.nextInt(_boundaryCharacters.length)],
        growable: false);
    return "$prefix${new String.fromCharCodes(list)}";
  }
}
