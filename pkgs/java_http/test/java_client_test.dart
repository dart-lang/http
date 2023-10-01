// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:java_http/java_http.dart';
import 'package:test/test.dart';

void main() {
  group('java_http client conformance tests', () {
    testIsolate(JavaClient.new);
    testResponseBody(JavaClient());
    testResponseBodyStreamed(JavaClient());
    testResponseHeaders(JavaClient());
    testResponseStatusLine(JavaClient());
    testRequestBody(JavaClient());
    testRequestHeaders(JavaClient());
    testMultipleClients(JavaClient.new);
  });
}
