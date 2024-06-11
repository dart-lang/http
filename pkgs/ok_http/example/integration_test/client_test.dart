// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ok_http/ok_http.dart';
import 'package:test/test.dart';

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  await testConformance();
}

Future<void> testConformance() async {
  group('ok_http client', () {
    testRequestBody(OkHttpClient());
    testResponseBody(OkHttpClient(), canStreamResponseBody: false);
    testRequestHeaders(OkHttpClient());
    testRequestMethods(OkHttpClient(), preservesMethodCase: true);
    testResponseHeaders(OkHttpClient(), supportsFoldedHeaders: false);
    testResponseStatusLine(OkHttpClient());
    testCompressedResponseBody(OkHttpClient());
    testRedirect(OkHttpClient());
    testServerErrors(OkHttpClient());
    testClose(OkHttpClient.new);
    testIsolate(OkHttpClient.new);
    testRequestCookies(OkHttpClient(), canSendCookieHeaders: true);
    testResponseCookies(OkHttpClient(), canReceiveSetCookieHeaders: true);
  });
}
