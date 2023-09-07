// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cronet_http/cronet_http.dart';
import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

void testClientConformance(CronetClient Function() clientFactory) {
  testAll(clientFactory, canStreamRequestBody: false, canWorkInIsolates: false);
}

Future<void> testConformance() async {
  group('default cronet engine',
      () => testClientConformance(CronetClient.defaultCronetEngine));

  final engine = CronetEngine.build(
      cacheMode: CacheMode.disabled, userAgent: 'Test Agent (Engine)');

  group('from cronet engine', () {
    testClientConformance(() => CronetClient.fromCronetEngine(engine));
  });

  group('from cronet engine future', () {
    final engine = CronetEngine.build(
        cacheMode: CacheMode.disabled, userAgent: 'Test Agent (Future)');
    testClientConformance(() => CronetClient.fromCronetEngine(engine));
  });
}

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  await testConformance();
}
