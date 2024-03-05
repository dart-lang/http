// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../web_socket.dart';

Future<WebSocket> connect(Uri url, {Iterable<String>? protocols}) {
  throw UnsupportedError('Cannot connect without dart:js_interop or dart:io.');
}
