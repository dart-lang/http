// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The current resident set size (RSS) of the process in bytes.
///
/// Always returns `null` because process RSS is unavailable on web.
int? get currentRss => null;
