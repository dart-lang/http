// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:http_profile/http_profile.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('defaultSessionConfiguration', () {
    group('profile enabled', () {
      final profile = HttpClientRequestProfile.profilingEnabled;
      HttpClientRequestProfile.profilingEnabled = true;
      try {
        testAll(
          CupertinoClient.defaultSessionConfiguration,
          canReceiveSetCookieHeaders: true,
          canSendCookieHeaders: true,
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
          CupertinoClient.defaultSessionConfiguration,
          canReceiveSetCookieHeaders: true,
          canSendCookieHeaders: true,
        );
      } finally {
        HttpClientRequestProfile.profilingEnabled = profile;
      }
    });
  });
  group('fromSessionConfiguration', () {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration();
    testAll(
      () => CupertinoClient.fromSessionConfiguration(config),
      canWorkInIsolates: false,
      canReceiveSetCookieHeaders: true,
      canSendCookieHeaders: true,
    );
  });
}
