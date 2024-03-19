// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cupertino_http/src/native_cupertino_bindings.dart' as ncb;
import 'package:cupertino_http/src/utils.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('toStringOrNull', () {
    test('null input', () {
      expect(toStringOrNull(null), null);
    });

    test('string input', () {
      expect(toStringOrNull('Test'.toNSString(linkedLibs)), 'Test');
    });
  });

  group('stringNSDictionaryToMap', () {
    test('empty input', () {
      final d = ncb.NSMutableDictionary.new1(linkedLibs);

      expect(stringNSDictionaryToMap(d), <String, String>{});
    });

    test('single string input', () {
      final d = ncb.NSMutableDictionary.new1(linkedLibs)
        ..setObject_forKey_(
            'value'.toNSString(linkedLibs), 'key'.toNSString(linkedLibs));

      expect(stringNSDictionaryToMap(d), {'key': 'value'});
    });

    test('multiple string input', () {
      final d = ncb.NSMutableDictionary.new1(linkedLibs)
        ..setObject_forKey_(
            'value1'.toNSString(linkedLibs), 'key1'.toNSString(linkedLibs))
        ..setObject_forKey_(
            'value2'.toNSString(linkedLibs), 'key2'.toNSString(linkedLibs))
        ..setObject_forKey_(
            'value3'.toNSString(linkedLibs), 'key3'.toNSString(linkedLibs));
      expect(stringNSDictionaryToMap(d),
          {'key1': 'value1', 'key2': 'value2', 'key3': 'value3'});
    });
  });

  group('stringIterableToNSArray', () {
    test('empty input', () {
      final array = stringIterableToNSArray([]);
      expect(array.count, 0);
    });

    test('single string input', () {
      final array = stringIterableToNSArray(['apple']);
      expect(array.count, 1);
      expect(
          ncb.NSString.castFrom(array.objectAtIndex_(0)).toString(), 'apple');
    });

    test('multiple string input', () {
      final array = stringIterableToNSArray(['apple', 'banana']);
      expect(array.count, 2);
      expect(
          ncb.NSString.castFrom(array.objectAtIndex_(0)).toString(), 'apple');
      expect(
          ncb.NSString.castFrom(array.objectAtIndex_(1)).toString(), 'banana');
    });
  });
}
