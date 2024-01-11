// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cronet_http/cronet_http.dart';
import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

Future<void> testConformance() async {
  group(
      'default cronet engine',
      () => testAll(
            CronetClient.defaultCronetEngine,
            canStreamRequestBody: false,
            canReceiveSetCookieHeaders: true,
            canSendCookieHeaders: true,
          ));

  group('from cronet engine', () {
    testAll(
      () {
        final engine = CronetEngine.build(
            cacheMode: CacheMode.disabled, userAgent: 'Test Agent (Future)');
        return CronetClient.fromCronetEngine(engine);
      },
      canStreamRequestBody: false,
    );
  });
}

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  await testConformance();
}
