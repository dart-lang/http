// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'base_client.dart';
import 'request.dart';
import 'response.dart';

typedef Future<Response> Handler(Request request);
typedef void CloseHandler();

class HandlerClient extends BaseClient {
  final Handler _handler;
  final CloseHandler _close;

  HandlerClient(this._handler, this._close);

  Future<Response> send(Request request) => _handler(request);

  void close() {
    _close();
  }
}
