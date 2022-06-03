// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')

import 'package:http/browser_client.dart';
import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:test/test.dart';

void main() {
  final client = BrowserClient();

  group('testAll', () {
    // TODO: Replace this with `testAll` when all tests support browser testing.
    testRequestBody(client);
    testRedirect(client, redirectAlwaysAllowed: true);
    testRequestBodyStreamed(client, canStreamRequestBody: false);
  });
}
