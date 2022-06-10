// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:cupertinohttp/cupertinohttp.dart';

void main() {
  group('response', () {
    late URLResponse response;
    setUp(() async {
      final session = URLSession.sharedSession();
      final task = session.dataTaskWithRequest(URLRequest.fromUrl(
          Uri.parse('data:text/fancy;charset=utf-8,Hello%20World')));
      task.resume();
      while (task.state != URLSessionTaskState.urlSessionTaskStateCompleted) {
        // Let the event loop run.
        await Future.delayed(const Duration());
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
