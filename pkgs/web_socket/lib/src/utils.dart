// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

/// Throw if the given close code is not valid.
void checkCloseCode(int? code) {
  if (code != null) {
    RangeError.checkValueInInterval(code, 3000, 4999, 'code');
  }
}

/// Throw if the given close reason is not valid.
void checkCloseReason(String? reason) {
  if (reason != null && utf8.encode(reason).length > 123) {
    throw ArgumentError.value(reason, 'reason',
        'reason must be <= 123 bytes long when encoded as UTF-8');
  }
}
