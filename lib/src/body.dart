// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:collection/collection.dart';

import 'utils.dart';

/// The body of a request or response.
///
/// This tracks whether the body has been read. It's separate from [Message]
/// because the message may be changed with [Message.change], but each instance
/// should share a notion of whether the body was read.
class Body {
  /// The contents of the message body.
  ///
  /// This will be `null` after [read] is called.
  Stream<List<int>> _stream;

  /// The encoding used to encode the stream returned by [read], or `null` if no
  /// encoding was used.
  final Encoding encoding;

  /// The length of the stream returned by [read], or `null` if that can't be
  /// determined efficiently.
  final int contentLength;

  /// An empty stream for use with empty bodies.
  static const _emptyStream = const Stream.empty();

  Body._(this._stream, this.encoding, this.contentLength);

  /// Converts [body] to a byte stream and wraps it in a [Body].
  ///
  /// [body] may be either a [Body], a [String], a [List<int>], a
  /// [Stream<List<int>>], or `null`. If it's a [String], [encoding] will be
  /// used to convert it to a [Stream<List<int>>].
  factory Body(body, [Encoding encoding]) {
    if (body is Body) return body;
    if (body == null) {
      return new Body._(_emptyStream, encoding, 0);
    }

    Stream<List<int>> stream;
    int contentLength;

    encoding ??= UTF8;

    if (body is Map) {
      body = mapToQuery(body, encoding: encoding);
    }

    if (body is String) {
      var encoded = encoding.encode(body);
      contentLength = encoded.length;
      stream = new Stream.fromIterable([encoded]);
    } else if (body is List) {
      contentLength = body.length;
      stream = new Stream.fromIterable([DelegatingList.typed(body)]);
    } else if (body is Stream) {
      stream = DelegatingStream.typed(body);
    } else {
      throw new ArgumentError('Response body "$body" must be a String or a '
          'Stream.');
    }

    return new Body._(stream, encoding, contentLength);
  }

  /// Returns a [Stream] representing the body.
  ///
  /// Can only be called once.
  Stream<List<int>> read() {
    if (_stream == null) {
      throw new StateError("The 'read' method can only be called once on a "
          "http.Request/http.Response object.");
    }
    var stream = _stream;
    _stream = null;
    return stream;
  }
}
