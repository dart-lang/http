// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Always returns `0` because process RSS is unavailable on web, so RSS growth
/// checks always pass.
int currentRss() => 0;

/// Does nothing because RSS is not measured on web.
Future<void> collectGarbage() async {}
