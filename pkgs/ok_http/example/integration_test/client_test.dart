// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:http_profile/http_profile.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ok_http/ok_http.dart';
import 'package:test/test.dart';

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  await testConformance();
}

Future<void> testConformance() async {
  group('ok_http client', () {
    group('profile enabled', () {
      final profile = HttpClientRequestProfile.profilingEnabled;
      HttpClientRequestProfile.profilingEnabled = true;

      try {
        testAll(
          OkHttpClient.new,
          canStreamRequestBody: false,
          preservesMethodCase: true,
          supportsFoldedHeaders: false,
          canSendCookieHeaders: true,
          canReceiveSetCookieHeaders: true,
        );
      } finally {
        HttpClientRequestProfile.profilingEnabled = profile;
      }
    });

    group('profile disabled', () {
      final profile = HttpClientRequestProfile.profilingEnabled;
      HttpClientRequestProfile.profilingEnabled = false;

      try {
        testAll(
          OkHttpClient.new,
          canStreamRequestBody: false,
          preservesMethodCase: true,
          supportsFoldedHeaders: false,
          canSendCookieHeaders: true,
          canReceiveSetCookieHeaders: true,
        );
      } finally {
        HttpClientRequestProfile.profilingEnabled = profile;
      }
    });
  });
}
