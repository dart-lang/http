// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'base_client.dart';
import 'handler.dart';
import 'request.dart';
import 'response.dart';

/// A [Handler]-based HTTP client.
///
/// The [HandlerClient] allows composition of a [Client] within a larger
/// application.
class HandlerClient extends BaseClient {
  final Handler _handler;
  final void Function() _close;

  /// Creates a new client using the [_handler] and [onClose] functions.
  HandlerClient(this._handler, void onClose())
      : _close = onClose;

  /// Sends an HTTP request and asynchronously returns the response.
  Future<Response> send(Request request) => _handler(request);

  /// Closes the client and cleans up any resources associated with it.
  void close() {
    _close();
  }
}
