// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

import 'http_unmodifiable_map.dart';

/// Adds a header with [name] and [value] to [headers], which may be null.
///
/// Returns a new map without modifying [headers].
Map<String, String> addHeader(
    Map<String, String> headers, String name, String value) {
  final modified = headers == null
      ? <String, String>{}
      : new Map<String, String>.from(headers);
  modified[name] = value;
  return modified;
}

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

/// Returns whether [headers] contains a header with the given [name].
///
/// This works even if [headers] is `null`, or if it's not yet a
/// case-insensitive map.
bool hasHeader(Map<String, String> headers, String name) {
  if (headers == null) return false;
  if (headers is HttpUnmodifiableMap) return headers.containsKey(name);

  for (var key in headers.keys) {
    if (equalsIgnoreAsciiCase(key, name)) return true;
  }
  return false;
}
