// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart';
import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

void testClientConformance(CronetClient Function() clientFactory) {
  testAll(clientFactory, canStreamRequestBody: false, canWorkInIsolates: false);
}

Future<void> testConformance() async {
  group('default cronet engine',
      () => testClientConformance(CronetClient.defaultCronetEngine));

  final engine = await CronetEngine.build(
      cacheMode: CacheMode.disabled, userAgent: 'Test Agent (Engine)');

  group('from cronet engine', () {
    testClientConformance(() => CronetClient.fromCronetEngine(engine));
  });

  group('from cronet engine future', () {
    final engineFuture = CronetEngine.build(
        cacheMode: CacheMode.disabled, userAgent: 'Test Agent (Future)');
    testClientConformance(
        () => CronetClient.fromCronetEngineFuture(engineFuture));
  });
}

Future<void> testClientFromFutureFails() async {
  test('cronet engine future fails', () async {
    final engineFuture = CronetEngine.build(
        cacheMode: CacheMode.disk,
        storagePath: '/non-existent-path/', // Will cause `build` to throw.
        userAgent: 'Test Agent (Future)');

    final client = CronetClient.fromCronetEngineFuture(engineFuture);
    await expectLater(
        client.get(Uri.http('example.com', '/')),
        throwsA((Exception e) =>
            e is ClientException &&
            e.message.contains('Exception building CronetEngine: '
                'Invalid argument(s): Storage path must')));
  });
}

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  await testConformance();
  await testClientFromFutureFails();
}
