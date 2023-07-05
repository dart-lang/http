// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('empty data', () {
    final data = MutableData.empty();

    test('length', () => expect(data.length, 0));
    test('bytes', () => expect(data.bytes, Uint8List(0)));
    test('toString', data.toString); // Just verify that there is no crash.
  });

  group('appendBytes', () {
    test('append no bytes', () {
      final data = MutableData.empty()..appendBytes(<int>[]);
      expect(data.bytes, Uint8List(0));
      data.toString(); // Just verify that there is no crash.
    });

    test('append some bytes', () {
      final data = MutableData.empty()..appendBytes([1, 2, 3, 4, 5]);
      expect(data.bytes, Uint8List.fromList([1, 2, 3, 4, 5]));
      data.appendBytes([6, 7, 8, 9, 10]);
      expect(data.bytes, Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));
      data.toString(); // Just verify that there is no crash.
    });
  });
}
