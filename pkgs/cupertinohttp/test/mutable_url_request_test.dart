// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:cupertinohttp/cupertinohttp.dart';

void main() {
  group('headers', () {
    final uri = Uri.parse('http://www.example.com/foo?baz=3#bar');
    late MutableURLRequest request;

    setUp(() => request = MutableURLRequest.fromUrl(uri));

    test('empty', () => expect(request.allHttpHeaderFields, null));
    test('add', () {
      request.setValueForHttpHeaderField('header', 'value');
      expect(request.allHttpHeaderFields!['header'], 'value');
      request.toString(); // Just verify that there is no crash.
    });
  });

  group('body', () {
    final uri = Uri.parse('http://www.example.com/foo?baz=3#bar');
    late MutableURLRequest request;

    setUp(() => request = MutableURLRequest.fromUrl(uri));

    test('empty', () => expect(request.httpBody, null));
    test('set', () {
      request.httpBody = Data.fromUint8List(Uint8List.fromList([1, 2, 3]));
      expect(request.httpBody!.bytes, Uint8List.fromList([1, 2, 3]));
      request.toString(); // Just verify that there is no crash.
    });
    test('set to null', () {
      request.httpBody = Data.fromUint8List(Uint8List.fromList([1, 2, 3]));
      request.httpBody = null;
      expect(request.httpBody, null);
    });
  });

  group('http method', () {
    final uri = Uri.parse('http://www.example.com/foo?baz=3#bar');
    late MutableURLRequest request;

    setUp(() => request = MutableURLRequest.fromUrl(uri));

    test('empty', () => expect(request.httpMethod, 'GET'));
    test('set', () {
      request.httpMethod = 'POST';
      expect(request.httpMethod, 'POST');
      request.toString(); // Just verify that there is no crash.
    });
  });
}
