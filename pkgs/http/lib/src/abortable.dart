// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'base_request.dart';
import 'client.dart';
import 'exception.dart';

/// Enables a request to be recognised by a [Client] as abortable
abstract mixin class Abortable implements BaseRequest {
  /// This request will be aborted if this completes
  ///
  /// A common pattern is aborting a request when another event occurs (such as
  /// a user action). A [Completer] may be used to implement this.
  ///
  /// Another pattern is a timeout. Use [Future.delayed] to achieve this.
  ///
  /// This future must not complete to an error.
  ///
  /// This future may complete at any time - a [AbortedRequest] will be thrown
  /// by [send]/[Client.send] if it is completed before the request is complete.
  ///
  /// Non-'package:http' [Client]s may unexpectedly not support this trigger.
  abstract final Future<void>? abortTrigger;
}

/// Thrown when a HTTP request is aborted
///
/// Usually, this is due to [Abortable.abortTrigger] completing before the
/// request is already complete. However, some clients' [Client.close]
/// implementation may cause open requests to throw this (or a standard
/// [ClientException]).
class AbortedRequest implements Exception {
  /// Indicator that the request has been aborted
  const AbortedRequest();
}
