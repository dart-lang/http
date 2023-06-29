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
    final data = Data.fromList(<int>[]);

    test('length', () => expect(data.length, 0));
    test('bytes', () => expect(data.bytes, Uint8List(0)));
    test('toString', data.toString); // Just verify that there is no crash.
  });

  group('non-empty data', () {
    final data = Data.fromList([1, 2, 3, 4, 5]);
    test('length', () => expect(data.length, 5));
    test(
        'bytes', () => expect(data.bytes, Uint8List.fromList([1, 2, 3, 4, 5])));
    test('toString', data.toString); // Just verify that there is no crash.
  });

  group('Data.fromData', () {
    test('from empty', () {
      final from = Data.fromList(<int>[]);
      expect(Data.fromData(from).bytes, Uint8List(0));
    });

    test('from non-empty', () {
      final from = Data.fromList([1, 2, 3, 4, 5]);
      expect(Data.fromData(from).bytes, Uint8List.fromList([1, 2, 3, 4, 5]));
    });
  });
}
