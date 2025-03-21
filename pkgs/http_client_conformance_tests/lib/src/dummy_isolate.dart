// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

// ignore: avoid_classes_with_only_static_members
/// An Isolate implementation for the web that throws when used.
abstract class Isolate {
  static Future<R> run<R>(FutureOr<R> Function() computation,
          {String? debugName}) =>
      throw ArgumentError.value('true', 'canWorkInIsolates',
          'isolate tests are not supported on the web');
}
