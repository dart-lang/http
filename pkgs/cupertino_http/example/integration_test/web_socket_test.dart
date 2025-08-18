// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cupertino_http/cupertino_http.dart';
import 'package:objective_c/objective_c.dart';
import 'package:test/test.dart';

void main() {
  group('ConnectionException', () {
    test('toString', () {
      expect(
        ConnectionException(
          'failed to connect',
          NSError.errorWithDomain('NSURLErrorDomain'.toNSString(), code: -999),
        ).toString(),
        'CupertinoErrorWebSocketException: failed to connect '
        '[The operation couldn’t be completed. (NSURLErrorDomain error -999.)]',
      );
    });
  });
}
