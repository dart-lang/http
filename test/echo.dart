// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io'
    show
        HttpServer,
        HttpRequest,
        ServerSocket,
        SecurityContext,
        InternetAddress;

import 'utils.dart' show echoPort;

/// Simple HTTP server that listens for requests and echoes the request body
/// in the response. It is used for testing the http package.
main() async {
  final httpServer = await HttpServer.bind(InternetAddress.ANY_IP_V6, echoPort);
  print('Echo server listening on port ${httpServer.port} (http)');
  _serve(httpServer);
}

_serve(HttpServer httpServer) async {
  await for (HttpRequest request in httpServer) {
    final response = request.response;
    response.headers.add('Access-Control-Allow-Origin', '*');
    request.pipe(response);
  }
}
