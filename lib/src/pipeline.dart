// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'client.dart';
import 'middleware.dart';

/// A helper that makes it easy to compose a set of [Middleware] and a
/// [Client].
///
///     var client = const Pipeline()
///         .addMiddleware(loggingMiddleware)
///         .addMiddleware(basicAuthMiddleware)
///         .addHandler(new Client());
class Pipeline {
  final Pipeline _parent;
  final Middleware _middleware;

  const Pipeline()
      : _parent = null,
        _middleware = null;

  Pipeline._(this._parent, this._middleware);

  /// Returns a new [Pipeline] with [middleware] added to the existing set of
  /// [Middleware].
  ///
  /// [middleware] will be the last [Middleware] to process a request and
  /// the first to process a response.
  Pipeline addMiddleware(Middleware middleware) =>
      new Pipeline._(this, middleware);

  /// Returns a new [Client] with [client] as the final processor of a
  /// [Request] if all of the middleware in the pipeline have passed the request
  /// through.
  Client addClient(Client client) =>
      _middleware == null ? client : _parent.addClient(_middleware(client));

  /// Exposes this pipeline of [Middleware] as a single middleware instance.
  Middleware get middleware => addClient;
}
