// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('defaultSessionConfiguration', () {
    testAll(CupertinoClient.defaultSessionConfiguration,
        canStreamRequestBody: false);
  });
  group('fromSessionConfiguration', () {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration();
    testAll(() => CupertinoClient.fromSessionConfiguration(config),
        canStreamRequestBody: false, canWorkInIsolates: false);
  });
}
