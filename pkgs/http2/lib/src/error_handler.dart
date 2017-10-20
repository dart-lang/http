// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.src.error_handler;

import 'dart:async';

import 'sync_errors.dart';

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

  T ensureNotTerminatedSync<T>(T f()) {
    if (wasTerminated) {
      throw new TerminatedException();
    }
    return f();
  }

  Future ensureNotTerminatedAsync(Future f()) {
    if (wasTerminated) {
      return new Future.error(new TerminatedException());
    }
    return f();
  }
}

/// Used by classes which may be closed.
class ClosableMixin {
  bool _closing = false;
  final Completer _completer = new Completer();

  Future get done => _completer.future;

  bool get isClosing => _closing;
  bool get wasClosed => _completer.isCompleted;

  void startClosing() {
    if (!_closing) {
      _closing = true;

      onClosing();
    }
    onCheckForClose();
  }

  void onCheckForClose() {
    // Subclasses can override this method if they want.
  }

  void onClosing() {
    // Subclasses can override this method if they want.
  }

  dynamic ensureNotClosingSync(f()) {
    if (isClosing) {
      throw new StateError('Was in the process of closing.');
    }
    return f();
  }

  void closeWithValue([value]) {
    if (!wasClosed) {
      _completer.complete(value);
    }
  }

  void closeWithError(error) {
    if (!wasClosed) {
      _completer.complete(error);
    }
  }
}
