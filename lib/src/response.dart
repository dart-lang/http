// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http_parser/http_parser.dart';

import 'message.dart';
import 'utils.dart';

/// An HTTP response where the entire response body is known in advance.
class Response extends Message {
  /// The status code of the response.
  final int statusCode;

  /// Creates a new HTTP response with the [statusCode].
  Response(this.statusCode,
      {body,
      Encoding encoding,
      Map<String, String> headers,
      Map<String, Object> context})
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

    body ??= getBody(this);

    return new Response(this.statusCode,
        body: body, headers: updatedHeaders, context: updatedContext);
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
