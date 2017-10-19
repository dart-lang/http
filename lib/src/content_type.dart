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

/// Determines the encoding from the media [type].
///
/// Returns [fallback] if the charset is not specified in the [type] or if no
/// [Encoding] was found that corresponds to the `charset`.
Encoding encodingForMediaType(MediaType type, [Encoding fallback = LATIN1]) {
  if (type == null) return fallback;
  return encodingForCharset(type.parameters['charset'], fallback);
}

/// Modifies the media [type]'s [encoding].
MediaType modifyEncoding(MediaType type, Encoding encoding) =>
    type.change(parameters: <String, String>{'charset': encoding.name});
