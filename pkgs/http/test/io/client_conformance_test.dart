// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:http/io_client.dart';
import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:test/test.dart';

void main() {
  testAll(
    IOClient.new, preservesMethodCase: false, // https://dartbug.com/54187
    canReceiveSetCookieHeaders: true,
    canSendCookieHeaders: true,
    correctlyHandlesNullHeaderValues:
        false, // https://github.com/dart-lang/sdk/issues/56636
    supportsAbort: true,
  );
}
