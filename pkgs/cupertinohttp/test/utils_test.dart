// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:cupertinohttp/src/native_cupertino_bindings.dart' as ncb;
import 'package:cupertinohttp/src/utils.dart';

void main() {
  group('toStringOrNull', () {
    test('null input', () {
      expect(toStringOrNull(null), null);
    });

    test('string input', () {
      expect(toStringOrNull("Test".toNSString(linkedLibs)), "Test");
    });
  });

  group('stringDictToMap', () {
    test('empty input', () {
      final d = ncb.NSMutableDictionary.new1(linkedLibs);

      expect(stringDictToMap(d), {});
    });

    test('single string input', () {
      final d = ncb.NSMutableDictionary.new1(linkedLibs);
      d.setObject_forKey_(
          "value".toNSString(linkedLibs), "key".toNSString(linkedLibs));

      expect(stringDictToMap(d), {"key": "value"});
    });

    test('multiple string input', () {
      final d = ncb.NSMutableDictionary.new1(linkedLibs);
      d.setObject_forKey_(
          "value1".toNSString(linkedLibs), "key1".toNSString(linkedLibs));
      d.setObject_forKey_(
          "value2".toNSString(linkedLibs), "key2".toNSString(linkedLibs));
      d.setObject_forKey_(
          "value3".toNSString(linkedLibs), "key3".toNSString(linkedLibs));
      expect(stringDictToMap(d),
          {"key1": "value1", "key2": "value2", "key3": "value3"});
    });
  });
}
