// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';

void main() {
  group('parseAcceptHeader', () {
    test('parses empty header', () {
      expect(parseAcceptHeader(''), isEmpty);
    });

    test('parses simple header', () {
      final result = parseAcceptHeader('text/html');
      expect(result, hasLength(1));
      expect(result[0].mimeType, equals('text/html'));
    });

    test('parses multiple media types', () {
      final result = parseAcceptHeader('text/html, application/xhtml+xml');
      expect(result, hasLength(2));
      expect(result[0].mimeType, equals('text/html'));
      expect(result[1].mimeType, equals('application/xhtml+xml'));
    });

    test('sorts by quality factor q', () {
      final result =
          parseAcceptHeader('text/html;q=0.5, application/xhtml+xml;q=0.9');
      expect(result, hasLength(2));
      expect(result[0].mimeType, equals('application/xhtml+xml'));
      expect(result[1].mimeType, equals('text/html'));
    });

    test('sorts by specificity', () {
      final result = parseAcceptHeader('*/*, text/*, text/html');
      expect(result, hasLength(3));
      expect(result[0].mimeType, equals('text/html'));
      expect(result[1].mimeType, equals('text/*'));
      expect(result[2].mimeType, equals('*/*'));
    });

    test('sorts by specificity with equal q', () {
      final result =
          parseAcceptHeader('*/*;q=0.9, text/*;q=0.9, text/html;q=0.9');
      expect(result, hasLength(3));
      expect(result[0].mimeType, equals('text/html'));
      expect(result[1].mimeType, equals('text/*'));
      expect(result[2].mimeType, equals('*/*'));
    });

    test('sorts by number of parameters with equal q and specificity', () {
      final result = parseAcceptHeader('text/html;foo=bar, text/html');
      expect(result, hasLength(2));
      expect(result[0].parameters, containsPair('foo', 'bar'));
      expect(result[1].parameters, isEmpty);
    });

    test('handles invalid media types gracefully (throws FormatError)', () {
      expect(
          () => parseAcceptHeader('invalid_media_type'), throwsFormatException);
    });

    test('handles empty elements (ignores them)', () {
      final result = parseAcceptHeader('text/html,, application/xhtml+xml');
      expect(result, hasLength(2));
      expect(result[0].mimeType, equals('text/html'));
      expect(result[1].mimeType, equals('application/xhtml+xml'));
    });

    test('handles whitespace around commas', () {
      final result = parseAcceptHeader('text/html , application/xhtml+xml');
      expect(result, hasLength(2));
      expect(result[0].mimeType, equals('text/html'));
      expect(result[1].mimeType, equals('application/xhtml+xml'));
    });
  });
}
