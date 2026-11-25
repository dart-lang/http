// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

/// Whether [HttpClient.enableTimelineLogging] is enabled.
///
/// When enabled, request and response bodies are retained for profiling, both
/// by `dart:io` and by `package:http_profile` (whose `profilingEnabled` is
/// backed by the same flag).
bool get timelineLoggingEnabled => HttpClient.enableTimelineLogging;
