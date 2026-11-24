// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

/// Returns the current resident set size (RSS) of the process in bytes.
int currentRss() => ProcessInfo.currentRss;

/// Holds the latest allocation made by [collectGarbage] so that the
/// allocations can't be optimized away.
final _garbage = <Uint8List>[];

/// Allocates short-lived memory until two full garbage collections complete.
///
/// Native memory owned by Dart objects (e.g. `NSData` referenced through
/// `package:objective_c`) is only freed when those objects are finalized. The
/// garbage collector is not aware of that memory so, without this, it can
/// accumulate across many requests and look like a leak.
///
/// This doesn't use `Dart_ExecuteInternalCommand("gc-now")`, like the
/// `dart-lang/native` tests do, because that symbol is not available in
/// Flutter applications (e.g. the Cronet tests on Android).
Future<void> collectGarbage() async {
  final barrier = reachabilityBarrier;
  final stopwatch = Stopwatch()..start();
  while (reachabilityBarrier < barrier + 2 &&
      stopwatch.elapsed < const Duration(seconds: 10)) {
    _garbage
      ..clear()
      ..add(Uint8List(4 * 1024 * 1024));
    await Future<void>.delayed(Duration.zero);
  }
  _garbage.clear();
}
