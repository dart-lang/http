// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'base_request.dart';
import 'client.dart';
import 'streamed_response.dart';

/// Enables a request to be recognised by a [Client] as abortable
abstract mixin class Abortable implements BaseRequest {
  /// Completion of this future aborts this request (if the client supports
  /// abortion)
  ///
  /// Requests/responses may be aborted at any time during their lifecycle.
  ///
  ///  * If completed before the request has been finalized and sent,
  ///    [Client.send] completes with an [AbortedRequest] exception
  ///  * If completed after the response headers are available, or whilst
  ///    streaming response bytes, clients inject [AbortedRequest] into the
  ///    [StreamedResponse.stream] then finish it early
  ///  * If completed after the response is fully complete, there is no effect
  ///
  /// A common pattern is aborting a request when another event occurs (such as
  /// a user action): use a [Completer] to implement this. To implement a
  /// timeout (to abort the request after a set time has elapsed), use
  /// [Future.delayed].
  ///
  /// This future must not complete to an error.
  ///
  /// Some clients may not support abortion, or may not support this trigger.
  abstract final Future<void>? abortTrigger;
}

/// Thrown when an HTTP request is aborted
///
/// Usually, this is due to [Abortable.abortTrigger]. See documentation on that
/// property for more info.
class AbortedRequest implements Exception {
  /// Indicator that the request has been aborted
  const AbortedRequest();
}
