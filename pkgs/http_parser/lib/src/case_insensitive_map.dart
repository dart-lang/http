// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

/// A map from case-insensitive strings to values.
///
/// Much of HTTP is case-insensitive, so this is useful to have pre-defined.
class CaseInsensitiveMap<V> extends CanonicalizedMap<String, String, V> {
  /// Creates an empty case-insensitive map.
  CaseInsensitiveMap() : super(_canonicalizer);

  /// Creates a case-insensitive map that is initialized with the key/value
  /// pairs of [other].
  CaseInsensitiveMap.from(Map<String, V> other)
      : super.from(other, _canonicalizer);

  /// Creates a case-insensitive map that is initialized with the key/value
  /// pairs of [entries].
  CaseInsensitiveMap.fromEntries(Iterable<MapEntry<String, V>> entries)
      : super.fromEntries(entries, _canonicalizer);

  static String _canonicalizer(String key) => key.toLowerCase();
}
