// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

/// A map from case-insensitive strings to values.
///
/// Much of HTTP is case-insensitive, so this is useful to have pre-defined.
extension type CaseInsensitiveMap<V>._(Map<String, V> _)
    implements Map<String, V> {
  /// Creates an empty case-insensitive map.
  CaseInsensitiveMap()
      : this._(CanonicalizedMap<String, String, V>(_canonicalize));

  /// Creates a case-insensitive map initialized with the entries of [other].
  CaseInsensitiveMap.from(Map<String, V> other)
      : this._(CanonicalizedMap<String, String, V>.from(other, _canonicalize));

  /// Creates a case-insensitive map initialized with the [entries].
  CaseInsensitiveMap.fromEntries(Iterable<MapEntry<String, V>> entries)
      : this._(CanonicalizedMap<String, String, V>.fromEntries(
            entries, _canonicalize));

  static String _canonicalize(String key) => key.toLowerCase();
}
