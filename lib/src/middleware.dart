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
  void errorHandler(error, [StackTrace stackTrace])
}) {
  requestHandler ??= (request) async => request;
  responseHandler ??= (response) async => response;

  return (inner) {
    return new HandlerClient(
      (request) =>
        requestHandler(request)
            .then((req) => inner.send(req))
            .then((res) => responseHandler(res), onError: errorHandler),
        onClose == null
            ? inner.close
            : () {
                onClose();
                inner.close();
              },
    );
  };
}
