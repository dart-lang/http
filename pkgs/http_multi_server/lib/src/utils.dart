// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

/// A cache for [supportsIpV6].
bool _supportsIpV6;

/// Returns whether this computer supports binding to IPv6 addresses.
Future<bool> get supportsIpV6 async {
  if (_supportsIpV6 != null) return _supportsIpV6;

  try {
    var socket = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V6, 0);
    _supportsIpV6 = true;
    socket.close();
    return true;
  } on SocketException catch (_) {
    _supportsIpV6 = false;
    return false;
  }
}
