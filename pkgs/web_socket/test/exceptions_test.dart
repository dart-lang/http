// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

void main() {
  group('WebSocketException', () {
    test('no message', () async {
      final exception = WebSocketException();
      expect(exception.message, isEmpty);
      expect(exception.toString(), 'WebSocketException');
    });

    test('with message', () async {
      final exception = WebSocketException('bad connection');
      expect(exception.message, 'bad connection');
      expect(exception.toString(), 'WebSocketException: bad connection');
    });
  });

  group('WebSocketConnectionClosed', () {
    test('no message', () async {
      final exception = WebSocketConnectionClosed();
      expect(exception.message, 'Connection Closed');
      expect(
          exception.toString(), 'WebSocketConnectionClosed: Connection Closed');
    });

    test('empty message', () async {
      final exception = WebSocketConnectionClosed('');
      expect(exception.message, isEmpty);
      expect(exception.toString(), 'WebSocketConnectionClosed');
    });

    test('with message', () async {
      final exception = WebSocketConnectionClosed('bad connection');
      expect(exception.message, 'bad connection');
      expect(exception.toString(), 'WebSocketConnectionClosed: bad connection');
    });
  });
}
