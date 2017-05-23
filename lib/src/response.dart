// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http_parser/http_parser.dart';

import 'message.dart';
import 'utils.dart';

/// An HTTP response where the entire response body is known in advance.
class Response extends Message {
  /// The location of the requested resource.
  ///
  /// The value takes into account any redirects that occurred during the
  /// request.
  final Uri location;

  /// The status code of the response.
  final int statusCode;

  /// The reason phrase associated with the status code.
  final String reasonPhrase;

  /// Creates a new HTTP response for a resource at the [location], which can
  /// be a [Uri] or a [String], with the given [statusCode].
  ///
  /// [body] is the request body. It may be either a [String], a [List<int>], a
  /// [Stream<List<int>>], or `null` to indicate no body. If it's a [String],
  /// [encoding] is used to encode it to a [Stream<List<int>>]. It defaults to
  /// UTF-8.
  ///
  /// [headers] are the HTTP headers for the request. If [headers] is `null`,
  /// it is treated as empty.
  ///
  /// Extra [context] can be used to pass information between outer middleware
  /// and handlers.
  Response(location, int statusCode,
      {String reasonPhrase,
      body,
      Encoding encoding,
      Map<String, String> headers,
      Map<String, Object> context})
      : this._(getUrl(location), statusCode, reasonPhrase ?? '',
      body, encoding, headers, context);

  Response._(this.location, this.statusCode, this.reasonPhrase,
      body,
      Encoding encoding,
      Map<String, String> headers,
      Map<String, Object> context)
      : super(body, encoding: encoding, headers: headers, context: context);

  /// Creates a new [Response] by copying existing values and applying specified
  /// changes.
  ///
  /// New key-value pairs in [context] and [headers] will be added to the copied
  /// [Response].
  ///
  /// If [context] or [headers] includes a key that already exists, the
  /// key-value pair will replace the corresponding entry in the copied
  /// [Response].
  ///
  /// All other context and header values from the [Response] will be included
  /// in the copied [Response] unchanged.
  ///
  /// [body] is the request body. It may be either a [String], a [List<int>], a
  /// [Stream<List<int>>], or `null` to indicate no body.
  Response change(
      {Map<String, String> headers,
      Map<String, Object> context,
      body}) {
    var updatedHeaders = updateMap(this.headers, headers);
    var updatedContext = updateMap(this.context, context);

    return new Response._(
        this.location,
        this.statusCode,
        this.reasonPhrase,
        body ?? getBody(this),
        this.encoding,
        updatedHeaders,
        updatedContext);
  }

  /// The date and time after which the response's data should be considered
  /// stale.
  ///
  /// This is parsed from the Expires header in [headers]. If [headers] doesn't
  /// have an Expires header, this will be `null`.
  DateTime get expires {
    if (_expiresCache != null) return _expiresCache;
    if (!headers.containsKey('expires')) return null;
    _expiresCache = parseHttpDate(headers['expires']);
    return _expiresCache;
  }
  DateTime _expiresCache;

  /// The date and time the source of the response's data was last modified.
  ///
  /// This is parsed from the Last-Modified header in [headers]. If [headers]
  /// doesn't have a Last-Modified header, this will be `null`.
  DateTime get lastModified {
    if (_lastModifiedCache != null) return _lastModifiedCache;
    if (!headers.containsKey('last-modified')) return null;
    _lastModifiedCache = parseHttpDate(headers['last-modified']);
    return _lastModifiedCache;
  }
  DateTime _lastModifiedCache;
}
