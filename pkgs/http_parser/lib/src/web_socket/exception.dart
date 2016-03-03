// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This class is deprecated.
///
/// Use the [`web_socket_channel`][web_socket_channel] package instead.
///
/// [web_socket_channel]: https://pub.dartlang.org/packages/web_socket_channel
@Deprecated("Will be removed in 3.0.0.")
class CompatibleWebSocketException implements Exception {
  final String message;

  CompatibleWebSocketException([this.message]);

  String toString() => message == null
      ? "CompatibleWebSocketException" :
        "CompatibleWebSocketException: $message";
}
