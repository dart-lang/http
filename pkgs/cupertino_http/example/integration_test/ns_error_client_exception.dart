// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:objective_c/objective_c.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NSErrorClientException', () {
    late CupertinoClient client;

    setUpAll(() => client = CupertinoClient.defaultSessionConfiguration());
    tearDownAll(() => client.close());

    test('thrown', () async {
      expect(
        () => client.get(Uri.http('doesnotexist', '/')),
        throwsA(
          isA<NSErrorClientException>()
              .having(
                (e) => e.error.domain.toDartString(),
                'error.domain',
                'NSURLErrorDomain',
              )
              .having((e) => e.error.code, 'error.code', -1003)
              .having(
                (e) => e.toString(),
                'toString()',
                'NSErrorClientException: A server with the specified '
                    'hostname could not be found. '
                    '[domain=NSURLErrorDomain, code=-1003], '
                    'uri=http://doesnotexist/',
              ),
        ),
      );
    });
  });
}
