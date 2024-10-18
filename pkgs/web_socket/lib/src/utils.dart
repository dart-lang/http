// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

/// Throw if the given close code is not valid according to WHATWG spec.
/// 
/// This is more suitable for clients running in web browsers.
/// 
/// See https://websockets.spec.whatwg.org/#dom-websocket-close.
void checkCloseCodeWeb(int? code) {
  if (code != null && code != 1000 && !(code >= 3000 && code <= 4999)) {
    throw ArgumentError('Invalid argument: $code, close code must be 1000 or '
        'in the range 3000-4999');
  }
}

/// Throw if the given close code is not valid according to RFC 6455.
/// 
/// This is more suitable for clients running in native environments, possibly
/// as a server endpoint.
/// 
/// See https://www.rfc-editor.org/rfc/rfc6455.html#section-7.4
void checkCloseCodeRfc(int? code) {
  const reservedCloseCodes = [1004, 1005, 1006];
  if (code != null &&
      !(code >= 1000 && code <= 1011 && !reservedCloseCodes.contains(code)) &&
      !(code >= 3000 && code <= 4999)) {
    throw ArgumentError(
      'Invalid argument: $code, close code must be in the range 1000-1011 or '
      'in the range 3000-4999, and cannot be one of reserved codes '
      '(${reservedCloseCodes.join(', ')})',
    );
  }
}

/// Throw if the given close reason is not valid.
void checkCloseReason(String? reason) {
  if (reason != null && utf8.encode(reason).length > 123) {
    throw ArgumentError.value(reason, 'reason',
        'reason must be <= 123 bytes long when encoded as UTF-8');
  }
}
