// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http_parser/http_parser.dart';

/// Returns the [Encoding] that corresponds to [charset].
///
/// Returns [fallback] if [charset] is null or if no [Encoding] was found that
/// corresponds to [charset].
Encoding encodingForCharset(String charset, [Encoding fallback = LATIN1]) {
  if (charset == null) return fallback;
  var encoding = Encoding.getByName(charset);
  return encoding == null ? fallback : encoding;
}

/// Returns the name of the charset that corresponds to the [contentType].
///
/// If [contentType] is `null` then no charset has been specified and `null`
/// will be returned. If the [contentType] is present then it will be parsed
/// and the value of `charset` is returned.
String charsetForContentType(String contentType) {
  if (contentType == null) return null;
  var mediaType = new MediaType.parse(contentType);
  return mediaType.parameters['charset'];
}

/// Determines the body encoding either through an explicit [encoding] or
/// through the [contentType] header.
///
/// If an explicit [encoding] is set then this will be used and will override
/// any `charset` from [contentType]. Otherwise the [contentType]'s `charset`
/// will be used. If neither are provided `null` will be returned.
Encoding determineEncoding(Encoding encoding, String contentType) {
  if (encoding != null) return encoding;
  var charset = charsetForContentType(contentType);
  return encodingForCharset(charset, null);
}
