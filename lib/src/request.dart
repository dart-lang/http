// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'message.dart';
import 'utils.dart';

/// Represents an HTTP request to be processed by a `http` application.
class Request extends Message {
  /// The HTTP method of the request. Most commonly "GET" or "POST", less
  /// commonly "HEAD", "PUT", or "DELETE". Non-standard method names are also
  /// supported.
  final String method;

  /// The URL to which the request will be sent.
  final Uri url;

  /// Creates a new [Request] for [url] using [method].
  Request(this.method, this.url,
      {body,
      Encoding encoding,
      Map<String, String> headers,
      Map<String, Object> context})
      : super(body, encoding: encoding, headers: headers, context: context);

  /// Creates a new [Request] for [url] using a "HEAD" method.
  Request.head(Uri url,
      {Map<String, String> headers, Map<String, Object> context})
      : this('HEAD', url, headers: headers, context: context);

  /// Creates a new [Request] for [url] using a "GET" method.
  Request.get(Uri url,
      {Map<String, String> headers, Map<String, Object> context})
      : this('GET', url, headers: headers, context: context);

  /// Creates a new [Request] for [url] using a "POST" method.
  Request.post(Uri url,
      body,
      {Encoding encoding,
      Map<String, String> headers,
      Map<String, Object> context})
      : this('POST', url,
      body: body, encoding: encoding, headers: headers, context: context);

  /// Creates a new [Request] for [url] using a "PUT" method.
  Request.put(Uri url,
      body,
      {Encoding encoding,
      Map<String, String> headers,
      Map<String, Object> context})
      : this('PUT', url,
      body: body, encoding: encoding, headers: headers, context: context);

  /// Creates a new [Request] for [url] using a "PATCH" method.
  Request.patch(Uri url,
      body,
      {Encoding encoding,
      Map<String, String> headers,
      Map<String, Object> context})
      : this('PATCH', url,
      body: body, encoding: encoding, headers: headers, context: context);

  /// Creates a new [Request] for [url] using a "DELETE" method.
  Request.delete(Uri url,
      {Map<String, String> headers, Map<String, Object> context})
      : this('DELETE', url, headers: headers, context: context);

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

    body ??= getBody(this);

    return new Request(this.method, this.url,
        body: body,
        encoding: this.encoding,
        headers: updatedHeaders,
        context: updatedContext);
  }
}
