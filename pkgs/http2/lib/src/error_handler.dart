// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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

  T ensureNotTerminatedSync<T>(T Function() f) {
    if (wasTerminated) {
      throw TerminatedException();
    }
    return f();
  }

  Future ensureNotTerminatedAsync(Future Function() f) {
    if (wasTerminated) {
      return Future.error(TerminatedException());
    }
    return f();
  }
}

/// Used by classes which may be cancelled.
class CancellableMixin {
  bool _cancelled = false;
  final _cancelCompleter = Completer<void>.sync();

  Future<void> get onCancel => _cancelCompleter.future;

  /// Cancel this stream message queue. Further operations on it will fail.
  void cancel() {
    if (!wasCancelled) {
      _cancelled = true;
      _cancelCompleter.complete();
    }
  }

  bool get wasCancelled => _cancelled;
}

/// Used by classes which may be closed.
class ClosableMixin {
  bool _closing = false;
  final Completer _completer = Completer();

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

  dynamic ensureNotClosingSync(dynamic Function() f) {
    if (isClosing) {
      throw StateError('Was in the process of closing.');
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
