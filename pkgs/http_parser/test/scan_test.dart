// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http_parser/src/scan.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:test/test.dart';

void main() {
  group('expectQuotedString', () {
    test('no open quote', () {
      final scanner = StringScanner('test"');
      expect(
          () => expectQuotedString(scanner),
          throwsA(isA<StringScannerException>()
              .having((e) => e.offset, 'offset', 0)
              .having((e) => e.message, 'message', 'expected quoted string.')
              .having((e) => e.source, 'source', 'test"')));
      expect(scanner.isDone, isFalse);
      expect(scanner.lastMatch, null);
      expect(scanner.position, 0);
    });

    test('no close quote', () {
      final scanner = StringScanner('"test');
      expect(
          () => expectQuotedString(scanner),
          throwsA(isA<StringScannerException>()
              .having((e) => e.offset, 'offset', 0)
              .having((e) => e.message, 'message', 'expected quoted string.')
              .having((e) => e.source, 'source', '"test')));
      expect(scanner.isDone, isFalse);
      expect(scanner.lastMatch, null);
      expect(scanner.position, 0);
    });

    test('simple quoted', () {
      final scanner = StringScanner('"test"');
      expect(expectQuotedString(scanner), 'test');
      expect(scanner.isDone, isTrue);
      expect(scanner.lastMatch?.group(0), '"test"');
      expect(scanner.position, 6);
    });

    test(r'escaped \', () {
      final scanner = StringScanner(r'"escaped: \\"');
      expect(expectQuotedString(scanner), r'escaped: \');
      expect(scanner.isDone, isTrue);
      expect(scanner.lastMatch?.group(0), r'"escaped: \\"');
      expect(scanner.position, 13);
    });

    test(r'bare \', () {
      final scanner = StringScanner(r'"bare: \"');
      expect(
          () => expectQuotedString(scanner),
          throwsA(isA<StringScannerException>()
              .having((e) => e.offset, 'offset', 0)
              .having((e) => e.message, 'message', 'expected quoted string.')
              .having((e) => e.source, 'source', r'"bare: \"')));
      expect(scanner.isDone, isFalse);
      expect(scanner.lastMatch, null);
      expect(scanner.position, 0);
    });

    test(r'escaped "', () {
      final scanner = StringScanner(r'"escaped: \""');
      expect(expectQuotedString(scanner), r'escaped: "');
      expect(scanner.isDone, isTrue);
      expect(scanner.lastMatch?.group(0), r'"escaped: \""');
      expect(scanner.position, 13);
    });
  });
}
