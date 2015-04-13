// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.src.error_handler;

/// Used by classes which may be terminated from the outside.
class TerminatableMixin {
  bool _terminated = false;

  /// Terminates this stream message queue. Further operations on it will fail.
  void terminate([error]) {
    if (!wasTerminated) {
      _terminated = true;
      onTerminated(error);
    }
  }

  bool get wasTerminated => _terminated;

  void onTerminated(error) {
    // Subclasses can override this method if they want.
  }
}
