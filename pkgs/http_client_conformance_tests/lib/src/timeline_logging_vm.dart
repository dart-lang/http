// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

/// Runs [action] with [HttpClient.enableTimelineLogging] disabled so repeated
/// multi-megabyte test payloads are not retained in the VM profiling buffer.
Future<T> withoutTimelineLogging<T>(Future<T> Function() action) async {
  final previous = HttpClient.enableTimelineLogging;
  HttpClient.enableTimelineLogging = false;
  try {
    return await action();
  } finally {
    HttpClient.enableTimelineLogging = previous;
  }
}
