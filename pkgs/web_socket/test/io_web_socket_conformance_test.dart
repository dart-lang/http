// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:web_socket/io_web_socket.dart';
import 'package:web_socket_conformance_tests/web_socket_conformance_tests.dart';

void main() {
  testAll(IOWebSocket.connect);
}
