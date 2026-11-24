// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

/// The current resident set size (RSS) of the process in bytes.
int? get currentRss() => ProcessInfo.currentRss;
