// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Tests that no [http.Client] is provided by default when run with
/// `--define=no_default_http_client=true`.
void main() {
  test('Client()', () {
    if (const bool.fromEnvironment('no_default_http_client')) {
      expect(http.Client.new, throwsA(isA<StateError>()));
    } else {
      expect(http.Client(), isA<http.Client>());
    }
  });
}
