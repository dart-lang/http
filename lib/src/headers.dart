// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

import 'http_unmodifiable_map.dart';

/// Returns the header with the given [name] in [headers].
///
/// This works even if [headers] is `null`, or if it's not yet a
/// case-insensitive map.
String getHeader(Map<String, String> headers, String name) {
  if (headers == null) return null;
  if (headers is HttpUnmodifiableMap) return headers[name];

  for (var key in headers.keys) {
    if (equalsIgnoreAsciiCase(key, name)) return headers[key];
  }
  return null;
}
