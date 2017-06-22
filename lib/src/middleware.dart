// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'client.dart';
import 'handler_client.dart';
import 'request.dart';
import 'response.dart';

/// A function which creates a new [Client] by wrapping a [Client].
///
/// You can extend the functions of a [Client] by wrapping it in [Middleware]
/// that can intercept and process a HTTP request before it it sent to a
/// client, a response after it is received by a client, or both.
///
/// Because [Middleware] consumes a [Client] and returns a new [Client],
/// multiple [Middleware] instances can be composed together to offer rich
/// functionality.
///
/// Common uses for middleware include caching, logging, and authentication.
///
/// A simple [Middleware] can be created using [createMiddleware].
typedef Client Middleware(Client inner);

/// Creates a [Middleware] using the provided functions.
///
/// If provided, [requestHandler] receives a [Request]. It replies to the
/// request by returning a [Future<Request>]. The modified [Request] is then
/// sent to the inner [Client].
///
/// If provided, [responseHandler] is called with the [Response] generated
/// by the inner [Client]. It replies to the response by returning a
/// [Future<Response]. The modified [Response] is then returned.
///
/// If provided, [onClose] will be invoked when the [Client.close] method is
/// called. Any cleanup of resources should happen at this point.
///
/// If provided, [errorHandler] receives errors thrown by the inner handler. It
/// does not receive errors thrown by [requestHandler] or [responseHandler].
/// It can either return a new response or throw an error.
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
