// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cupertino_http/src/utils.dart';
import 'package:integration_test/integration_test.dart';
import 'package:objective_c/objective_c.dart' as objc;
import 'package:test/test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('stringNSDictionaryToMap', () {
    test('empty input', () {
      final d = objc.NSMutableDictionary();

      expect(stringNSDictionaryToMap(d), <String, String>{});
    });

    test('single string input', () {
      final d = objc.NSMutableDictionary()
        ..setObject('value'.toNSString(), forKey: 'key'.toNSString());

      expect(stringNSDictionaryToMap(d), {'key': 'value'});
    });

    test('multiple string input', () {
      final d = objc.NSMutableDictionary()
        ..setObject('value1'.toNSString(), forKey: 'key1'.toNSString())
        ..setObject('value2'.toNSString(), forKey: 'key2'.toNSString())
        ..setObject('value3'.toNSString(), forKey: 'key3'.toNSString());
      expect(stringNSDictionaryToMap(d), {
        'key1': 'value1',
        'key2': 'value2',
        'key3': 'value3',
      });
    });

    test('non-string value', () {
      final d = objc.NSMutableDictionary()
        ..setObject(
          objc.NSNumberCreation.numberWithInteger(5),
          forKey: 'key'.toNSString(),
        );
      expect(() => stringNSDictionaryToMap(d), throwsUnsupportedError);
    });

    test('non-string key', () {
      final d = objc.NSMutableDictionary()
        ..setObject(
          'value'.toNSString(),
          forKey: objc.NSNumberCreation.numberWithInteger(5),
        );
      expect(() => stringNSDictionaryToMap(d), throwsUnsupportedError);
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
        objc.NSString.castFrom(array.objectAtIndex(0)).toDartString(),
        'apple',
      );
    });

    test('multiple string input', () {
      final array = stringIterableToNSArray(['apple', 'banana']);
      expect(array.count, 2);
      expect(
        objc.NSString.castFrom(array.objectAtIndex(0)).toDartString(),
        'apple',
      );
      expect(
        objc.NSString.castFrom(array.objectAtIndex(1)).toDartString(),
        'banana',
      );
    });
  });
}
