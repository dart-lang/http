// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'request.dart';
import 'response.dart';

/// The signature of a function which handles a [Request] and returns a
/// [Future<Response>].
///
/// A [Handler] may receive a request directly for a HTTP resource or it may be
/// composed as part of a larger application.
typedef Future<Response> Handler(Request request);
