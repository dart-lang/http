// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'channel.dart';

/// An exception thrown by [WebSocketChannel].
class CompatibleWebSocketException implements Exception {
  final String message;

  CompatibleWebSocketException([this.message]);

  String toString() => message == null
      ? "CompatibleWebSocketException" :
        "CompatibleWebSocketException: $message";
}
