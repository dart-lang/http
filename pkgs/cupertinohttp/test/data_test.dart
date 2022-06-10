// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:cupertinohttp/cupertinohttp.dart';

void main() {
  group('empty data', () {
    final data = Data.fromUint8List(Uint8List(0));

    test('length', () => expect(data.length, 0));
    test('bytes', () => expect(data.bytes, Uint8List(0)));
    test('toString',
        () => data.toString()); // Just verify that there is no crash.
  });

  group('non-empty data', () {
    final data = Data.fromUint8List(Uint8List.fromList([1, 2, 3, 4, 5]));
    test('length', () => expect(data.length, 5));
    test(
        'bytes', () => expect(data.bytes, Uint8List.fromList([1, 2, 3, 4, 5])));
    test('toString',
        () => data.toString()); // Just verify that there is no crash.
  });

  group('Data.fromData', () {
    test('from empty', () {
      final from = Data.fromUint8List(Uint8List(0));
      expect(Data.fromData(from).bytes, Uint8List.fromList([]));
    });

    test('from non-empty', () {
      final from = Data.fromUint8List(Uint8List.fromList([1, 2, 3, 4, 5]));
      expect(Data.fromData(from).bytes, Uint8List.fromList([1, 2, 3, 4, 5]));
    });
  });
}
