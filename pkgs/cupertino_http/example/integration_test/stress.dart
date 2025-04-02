// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:integration_test/integration_test.dart';

/// Stress tests not run as part of `main.dart` or
/// `flutter test integration_test`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  stressTestConcurrentRequests(CupertinoClient.defaultSessionConfiguration());
}
