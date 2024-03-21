// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

/// Tests that the [WebSocket] rejects invalid connection URIs.
void testConnectUri(
    Future<WebSocket> Function(Uri uri, {Iterable<String>? protocols})
        channelFactory) {
  group('connect uri', () {
    test('no protocol', () async {
      await expectLater(() => channelFactory(Uri.https('www.example.com', '/')),
          throwsA(isA<ArgumentError>()));
    });
  });
}
