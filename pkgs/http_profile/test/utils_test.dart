// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http_profile/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('splitHeaderValues', () {
    test('no headers', () async {
      expect(splitHeaderValues({}), const <String, List<String>>{});
    });

    test('one header', () async {
      expect(splitHeaderValues({'fruit': 'apple'}), const {
        'fruit': ['apple']
      });
    });

    test('two header', () async {
      expect(splitHeaderValues({'fruit': 'apple,banana'}), const {
        'fruit': ['apple', 'banana']
      });
    });

    test('two headers with lots of spaces', () async {
      expect(splitHeaderValues({'fruit': 'apple   \t   ,  \tbanana'}), const {
        'fruit': ['apple', 'banana']
      });
    });

    test('one set-cookie', () async {
      expect(
          splitHeaderValues({
            'set-cookie': 'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT'
          }),
          {
            'set-cookie': ['id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT']
          });
    });

    test('two set-cookie, with comma in expires', () async {
      expect(
          splitHeaderValues({
            // ignore: missing_whitespace_between_adjacent_strings
            'set-cookie': 'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT,'
                'sessionId=e8bb43229de9; Domain=foo.example.com'
          }),
          {
            'set-cookie': [
              'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT',
              'sessionId=e8bb43229de9; Domain=foo.example.com'
            ]
          });
    });

    test('two set-cookie, with lots of commas', () async {
      expect(
          splitHeaderValues({
            // ignore: missing_whitespace_between_adjacent_strings
            'set-cookie':
                // ignore: missing_whitespace_between_adjacent_strings
                'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO,'
                    'sessionId=e8bb43229de9; Domain=foo.example.com'
          }),
          {
            'set-cookie': [
              'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO',
              'sessionId=e8bb43229de9; Domain=foo.example.com'
            ]
          });
    });
  });
}
