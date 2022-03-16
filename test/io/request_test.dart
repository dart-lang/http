// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  setUp(startServer);

  tearDown(stopServer);

  test('send happy case', () async {
    Map<String, String> headers = {
      "a": "test",
      "b": "test",
      "c": "test",
      "d": "test"
    };
    final request =
        http.get(Uri.parse("http://127.0.0.1:5000"), headers: headers);

    final response = await request;

    expect(response.statusCode, equals(200));
  });
}
