// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'client.dart';
import 'handler_client.dart';
import 'request.dart';
import 'response.dart';

typedef Client Middleware(Client inner);

Middleware createMiddleware({
  Future<Request> requestHandler(Request request),
  Future<Response> responseHandler(Response response),
  void onClose(),
}) {
  requestHandler ??= (request) async => request;
  responseHandler ??= (response) async => response;
  onClose ??= () {};

  return (inner) {
    return new HandlerClient(
      (request) async {
        request = await requestHandler(request);

        var response = await inner.send(request);

        return await responseHandler(response);
      },
      () {
        onClose();

        // Ensure the inner close is called
        inner.close();
      },
    );
  };
}
