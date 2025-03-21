// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http/http.dart';
import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:test/test.dart';

class MyHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // Your implementation here.
    throw UnsupportedError('implement this method');
  }
}

void main() {
  group('client conformance tests', () {
    testAll(MyHttpClient.new);
  });
}
