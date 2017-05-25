// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'client.dart';
import 'handler_client.dart';
import 'request.dart';
import 'response.dart';

typedef Client Middleware(Client inner);

typedef Future<Response> ResponseHandler(Response response);
typedef Future<Request> RequestHandler(Request request);

Middleware createMiddleware({
  RequestHandler requestHandler,
  ResponseHandler responseHandler,
  CloseHandler closeHandler,
}) {
  requestHandler ??= (request) async => request;
  responseHandler ??= (response) async => response;
  closeHandler ??= () {};

  return (Client inner) {
    return new HandlerClient(
          (Request request) async {
        request = await requestHandler(request);

        final response = await inner.send(request);

        return await responseHandler(response);
      },
      () {
        closeHandler();

        inner.close();
      },
    );
  };
}
