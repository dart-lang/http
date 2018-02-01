// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:http/http.dart' as http;

import 'utils.dart';

void main() {
  group('expires', () {
    test('is null by default', () {
      var response = new http.Response(dummyUrl, 200);
      expect(response.expires, isNull);
    });

    test('is parsed from the header', () {
      var response = new http.Response(dummyUrl, 200,
          headers: {'Expires': 'Wed, 21 Oct 2015 07:28:00 GMT'});
      expect(response.expires, equals(new DateTime.utc(2015, 10, 21, 7, 28)));
    });

    test('throws a FormatException if the header is invalid', () {
      var message =
          new http.Response(dummyUrl, 200, headers: {'Expires': 'foobar'});
      expect(() => message.expires, throwsFormatException);
    });
  });

  group('lastModified', () {
    test('is null by default', () {
      var response = new http.Response(dummyUrl, 200);
      expect(response.lastModified, isNull);
    });

    test('is parsed from the header', () {
      var response = new http.Response(dummyUrl, 200,
          headers: {'Last-Modified': 'Wed, 21 Oct 2015 07:28:00 GMT'});
      expect(
          response.lastModified, equals(new DateTime.utc(2015, 10, 21, 7, 28)));
    });

    test('throws a FormatException if the header is invalid', () {
      var message = new http.Response(dummyUrl, 200,
          headers: {'Last-Modified': 'foobar'});
      expect(() => message.lastModified, throwsFormatException);
    });
  });
}
