// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:cupertinohttp/cupertinohttp.dart';

void main() {
  group('fromUrl', () {
    test('absolute URL', () {
      final uri = Uri.parse('http://www.example.com/foo?baz=3#bar');
      final request = URLRequest.fromUrl(uri);
      expect(request.url, uri);
      expect(request.httpMethod, 'GET');
      expect(request.allHttpHeaderFields, null);
      expect(request.httpBody, null);
      request.toString(); // Just verify that there is no crash.
    });

    test('relative URL', () {
      final uri = Uri.parse('/foo?baz=3#bar');
      final request = URLRequest.fromUrl(uri);
      expect(request.url, uri);
      expect(request.httpMethod, 'GET');
      expect(request.allHttpHeaderFields, null);
      expect(request.httpBody, null);
      request.toString(); // Just verify that there is no crash.
    });

    test('FTP URL', () {
      final uri = Uri.parse('ftp://ftp.example.com/foo');
      final request = URLRequest.fromUrl(uri);
      expect(request.url, uri);
      expect(request.httpMethod, 'GET');
      expect(request.allHttpHeaderFields, null);
      expect(request.httpBody, null);
      request.toString(); // Just verify that there is no crash.
    });
  });
}
