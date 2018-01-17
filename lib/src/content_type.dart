// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http_parser/http_parser.dart';

const String _textContentType = 'text/plain';
const String _urlEncodedType = 'application/x-www-form-urlencoded';
const String _defaultContentType = 'application/octet-stream';

/// Returns the [Encoding] that corresponds to [charset].
///
/// Returns `null` if [charset] is `null` or if no [Encoding] was found that
/// corresponds to [charset].
Encoding encodingForCharset(String charset) {
  if (charset == null) return null;
  return Encoding.getByName(charset);
}

/// Determines the encoding from the media [type].
///
/// Returns `null` if the charset is not specified in the [type] or if no
/// [Encoding] was found that corresponds to the `charset`.
Encoding encodingForMediaType(MediaType type) {
  if (type == null) return null;
  return encodingForCharset(type.parameters['charset']);
}

String guessContentType(contents, Encoding encoding) {
  if (contents is String) {
    return _contentType(_textContentType, encoding);
  } else if (contents is Map) {
    return _contentType(_urlEncodedType, encoding);
  } else if (encoding != null) {
    return _contentType(_defaultContentType, encoding);
  } else {
    return '';
  }
}

String _contentType(String contentType, Encoding encoding) {
  encoding ??= UTF8;

  return '$contentType; charset=${encoding.name}';
}
