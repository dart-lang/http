// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cupertino_http/cupertino_http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('error', () {
    test('simple', () {
      final e = Error.fromCustomDomain('test domain', 123);
      expect(e.code, 123);
      expect(e.domain, 'test domain');
      expect(e.localizedDescription,
          allOf(contains('test domain'), contains('123')));
      expect(e.localizedFailureReason, null);
      expect(e.localizedRecoverySuggestion, null);
      expect(e.toString(), allOf(contains('test domain'), contains('123')));
    });

    test('localized description', () {
      final e = Error.fromCustomDomain('test domain', 123,
          localizedDescription: 'This is a description');
      expect(e.code, 123);
      expect(e.domain, 'test domain');
      expect(e.localizedDescription, 'This is a description');
      expect(e.localizedFailureReason, null);
      expect(e.localizedRecoverySuggestion, null);
      expect(
          e.toString(),
          allOf(contains('test domain'), contains('123'),
              contains('This is a description')));
    });
  });
}
