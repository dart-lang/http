// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:objective_c/objective_c.dart';

/// Converts a NSDictionary containing NSString keys and NSString values into
/// an equivalent map.
Map<String, String> stringNSDictionaryToMap(NSDictionary d) {
  final m = <String, String>{};
  final keys = NSArray.castFrom(d.allKeys);
  for (var i = 0; i < keys.count; ++i) {
    final nsKey = keys.objectAtIndex_(i);
    if (!NSString.isInstance(nsKey)) {
      throw UnsupportedError('keys must be strings');
    }
    final key = NSString.castFrom(nsKey).toDartString();
    final nsValue = d.objectForKey_(nsKey);
    if (nsValue == null || !NSString.isInstance(nsValue)) {
      throw UnsupportedError('values must be strings');
    }
    final value = NSString.castFrom(nsValue).toDartString();
    m[key] = value;
  }

  return m;
}

NSArray stringIterableToNSArray(Iterable<String> strings) {
  final array = NSMutableArray.arrayWithCapacity_(strings.length);

  var index = 0;
  for (var s in strings) {
    array.setObject_atIndexedSubscript_(s.toNSString(), index++);
  }
  return array;
}

NSURL uriToNSURL(Uri uri) => NSURL.URLWithString_(uri.toString().toNSString())!;
Uri nsurlToUri(NSURL url) => Uri.parse(url.absoluteString!.toDartString());
