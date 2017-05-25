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
  Future<Request> onRequest(Request request),
  Future<Response> onResponse(Response response),
  void onClose(),
}) {
  onRequest ??= _defaultRequest;
  onResponse ??= _defaultResponse;
  onClose ??= _defaultClose;

  return (Client inner) {
    return new HandlerClient(
      (request) async {
        request = await onRequest(request);

        var response = await inner.send(request);

        return await onResponse(response);
      },
      () {
        onClose();

        // Ensure the inner close is called
        inner.close();
      },
    );
  };
}

Future<Request> _defaultRequest(Request request) async => request;
Future<Response> _defaultResponse(Response response) async => response;
void _defaultClose() {}
