// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http_multi_server/http_multi_server.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() async {
  // Both http://127.0.0.1:8080 and http://[::1]:8080 will be bound to the same
  // server.
  final server = await HttpMultiServer.loopback(8080);
  shelf_io.serveRequests(
    server,
    (request) => shelf.Response.ok('Hello, world!'),
  );
}
