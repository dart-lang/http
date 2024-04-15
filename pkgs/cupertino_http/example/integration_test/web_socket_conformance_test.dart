// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cupertino_http/cupertino_http.dart';
import 'package:test/test.dart';
import 'package:web_socket_conformance_tests/web_socket_conformance_tests.dart';

void main() {
  testAll(CupertinoWebSocket.connect);

  group('defaultSessionConfiguration', () {
    testAll(
      CupertinoWebSocket.connect,
    );
  });
  group('fromSessionConfiguration', () {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration();
    testAll((uri, {protocols}) =>
        CupertinoWebSocket.connect(uri, protocols: protocols, config: config));
  });
}
