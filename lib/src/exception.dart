// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// An exception caused by an error in a pkg/http client.
class ClientException implements Exception {
  /// Message describing the problem.
  final String message;

  /// The URL of the HTTP request or response that failed.
  final Uri uri;

  /// Creates a [ClientException] explained in [message].
  ///
  /// The [uri] points to the URL being requested if applicable.
  ClientException(this.message, [this.uri]);

  String toString() => message;
}
