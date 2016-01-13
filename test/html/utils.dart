// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

import '../utils.dart' show echoPort;
export '../utils.dart';

/// The echo server's URL.
Uri get echoUrl {
  var protocol = 'http';
  var host = window.location.host.split(':')[0];
  return Uri.parse('$protocol://$host:$echoPort');
}
