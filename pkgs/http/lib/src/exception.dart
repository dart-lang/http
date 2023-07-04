// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// An exception caused by an error in a pkg/http client.
class ClientException implements Exception {
  final String message;

  /// The URL of the HTTP request or response that failed.
  final Uri? uri;

  ClientException(this.message, [this.uri]);

  @override
  String toString() {
    if (uri != null) {
      return 'ClientException: $message, uri=$uri';
    } else {
      return 'ClientException: $message';
    }
  }
}

/// An exception caused by a request being cancelled programmatically.
// This is a separate exception to allow distinguishing between a request being
// cancelled and a request being aborted due to an error.
class CancelledException extends ClientException {
  CancelledException(super.message, [super.uri]);

  @override
  String toString() {
    if (uri != null) {
      return 'CancelledException: $message, uri=$uri';
    } else {
      return 'CancelledException: $message';
    }
  }
}
