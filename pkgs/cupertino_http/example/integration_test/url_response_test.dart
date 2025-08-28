// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cupertino_http/cupertino_http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('response', () {
    late URLResponse response;
    setUp(() async {
      final session = URLSession.sharedSession();
      final task = session.dataTaskWithRequest(
        URLRequest.fromUrl(
          Uri.parse('data:text/fancy;charset=utf-8,Hello%20World'),
        ),
      )..resume();
      while (task.state !=
          NSURLSessionTaskState.NSURLSessionTaskStateCompleted) {
        // Let the event loop run.
        await Future<void>.delayed(const Duration());
      }

      response = task.response!;
    });

    test('mimeType', () async {
      expect(response.mimeType, 'text/fancy');
    });

    test('expectedContentLength ', () {
      expect(response.expectedContentLength, 11);
    });

    test('toString', () {
      response.toString(); // Just verify that there is no crash.
    });
  });
}
