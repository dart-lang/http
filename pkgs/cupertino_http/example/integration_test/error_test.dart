// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@Skip('Error tests cannot currently be written. See comments in this file.')
library;

import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // TODO(https://github.com/dart-lang/ffigen/issues/386): Implement tests
  // when an initializer is callable.
}
