// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'body.dart';

/// An empty request body.
///
/// Used as an optimization when a `null` body is used.
class EmptyBody implements Body {
  /// An empty body is not encoded.
  Encoding get encoding => null;

  /// An empty body has no length.
  int get contentLength => 0;

  /// Creates an instance of [EmptyBody].
  const EmptyBody();

  /// Returns an empty [Stream] representing the body.
  Stream<List<int>> read() => const Stream<List<int>>.empty();
}
