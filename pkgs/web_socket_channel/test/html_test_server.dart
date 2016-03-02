// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

main() async {
  var server = await HttpServer.bind("localhost", 1234);
  server.transform(new WebSocketTransformer()).listen((webSocket) {
    print("connected");
    webSocket.listen((request) {
      print("got $request");
      webSocket.add(request);
    });
  });
}
