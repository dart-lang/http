// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'message.dart';
import 'utils.dart';

/// An HTTP response where the entire response body is known in advance.
class Response extends Message {
  /// The status code of the response.
  final int statusCode;

  /// Creates a new HTTP response with the [statusCode].
  Response(this.statusCode,
      {dynamic body,
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
      dynamic body}) {
    final updatedHeaders = updateMap/*<String, String>*/(this.headers, headers);
    final updatedContext = updateMap/*<String, Object>*/(this.context, context);

    body ??= getBody(this);

    return new Response(this.statusCode,
        body: body, headers: updatedHeaders, context: updatedContext);
  }
}
