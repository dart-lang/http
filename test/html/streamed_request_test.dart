// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')

import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('contentLength', () {
    test("works when it's set", () {
      var request = http.StreamedRequest('POST', echoUrl)
        ..contentLength = 10
        ..sink.add([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        ..sink.close();

      return BrowserClient().send(request).then((response) {
        expect(response.stream.toBytes(),
            completion(equals([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])));
      });
    });

    test("works when it's not set", () {
      var request = http.StreamedRequest('POST', echoUrl);
      request.sink.add([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      request.sink.close();

      return BrowserClient().send(request).then((response) {
        expect(response.stream.toBytes(),
            completion(equals([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])));
      });
    });
  }, skip: 'Need to fix server tests for browser');
}
