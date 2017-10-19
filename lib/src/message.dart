// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:http_parser/http_parser.dart';

import 'body.dart';
import 'content_type.dart';
import 'http_unmodifiable_map.dart';
import 'utils.dart';

/// Retrieves the [Body] contained in the [message].
///
/// This is meant for internal use by `http` so the message body is accessible
/// for subclasses of [Message] but hidden elsewhere.
Body getBody(Message message) => message._body;

/// Represents logic shared between [Request] and [Response].
abstract class Message {
  /// The HTTP headers.
  ///
  /// This is immutable. A copy of this with new headers can be created using
  /// [change].
  final Map<String, String> headers;

  /// Extra context that can be used by middleware and handlers.
  ///
  /// For requests, this is used to pass data to inner middleware and handlers;
  /// for responses, it's used to pass data to outer middleware and handlers.
  ///
  /// Context properties that are used by a particular package should begin with
  /// that package's name followed by a period. For example, if there was a
  /// package `foo` which contained a middleware `bar` and it wanted to take
  /// a context property, its property would be `"foo.bar"`.
  ///
  /// This is immutable. A copy of this with new context values can be created
  /// using [change].
  final Map<String, Object> context;

  /// The streaming body of the message.
  ///
  /// This can be read via [read] or [readAsString].
  final Body _body;

  /// Creates a new [Message].
  ///
  /// [body] is the message body. It may be either a [String], a [List<int>], a
  /// [Stream<List<int>>], or `null` to indicate no body. If it's a [String],
  /// [encoding] is used to encode it to a [Stream<List<int>>]. It defaults to
  /// UTF-8.
  ///
  /// If [headers] is `null`, it's treated as empty.
  ///
  /// If [encoding] is passed, the "encoding" field of the Content-Type header
  /// in [headers] will be set appropriately. If there is no existing
  /// Content-Type header, it will be set to "application/octet-stream".
  Message(body,
      {Encoding encoding,
      Map<String, String> headers,
      Map<String, Object> context})
      : this._(new Body(body, encoding), headers, context);

  Message._(Body body, Map<String, String> headers, Map<String, Object> context)
      : _body = body,
        headers = new HttpUnmodifiableMap<String>(_adjustHeaders(headers, body),
            ignoreKeyCase: true),
        context =
            new HttpUnmodifiableMap<Object>(context, ignoreKeyCase: false);

  /// If `true`, the stream returned by [read] won't emit any bytes.
  ///
  /// This may have false negatives, but it won't have false positives.
  bool get isEmpty => _body.contentLength == 0;

  /// The contents of the content-length field in [headers].
  ///
  /// If not set, `null`.
  int get contentLength {
    if (_contentLengthCache != null) return _contentLengthCache;
    var contentLengthHeader = getHeader(headers, 'content-length');
    if (contentLengthHeader == null) return null;
    return _contentLengthCache = int.parse(contentLengthHeader);
  }

  int _contentLengthCache;

  /// The MIME type declared in [headers].
  ///
  /// This is parsed from the Content-Type header in [headers]. It contains only
  /// the MIME type, without any Content-Type parameters.
  ///
  /// If [headers] doesn't have a Content-Type header, this will be `null`.
  String get mimeType => _contentType?.mimeType;

  /// The encoding of the body returned by [read].
  ///
  /// This is parsed from the "charset" parameter of the Content-Type header in
  /// [headers].
  ///
  /// If [headers] doesn't have a Content-Type header or it specifies an
  /// encoding that [dart:convert] doesn't support, this will be `null`.
  Encoding get encoding => encodingForMediaType(_contentType);

  /// The parsed version of the Content-Type header in [headers].
  ///
  /// This is cached for efficient access.
  MediaType get _contentType {
    if (_contentTypeCache != null) return _contentTypeCache;
    var contentLengthHeader = getHeader(headers, 'content-type');
    if (contentLengthHeader == null) return null;
    return _contentTypeCache = new MediaType.parse(contentLengthHeader);
  }

  MediaType _contentTypeCache;

  /// Returns the message body as byte chunks.
  ///
  /// Throws a [StateError] if [read] or [readAsString] has already been called.
  Stream<List<int>> read() => _body.read();

  /// Returns the message body as a string.
  ///
  /// If [encoding] is passed, that's used to decode the body. Otherwise the
  /// encoding is taken from the Content-Type header. If that doesn't exist or
  /// doesn't have a "charset" parameter, UTF-8 is used.
  ///
  /// Throws a [StateError] if [read] or [readAsString] has already been called.
  Future<String> readAsString([Encoding encoding]) {
    encoding ??= this.encoding ?? UTF8;
    return encoding.decodeStream(read());
  }

  /// Creates a copy of this by copying existing values and applying specified
  /// changes.
  Message change(
      {Map<String, String> headers, Map<String, Object> context, body});
}

/// Adds information about encoding to [headers].
///
/// Returns a new map without modifying [headers].
Map<String, String> _adjustHeaders(Map<String, String> headers, Body body) {
  var sameEncoding = _sameEncoding(headers, body);
  if (sameEncoding) {
    if (body.contentLength == null ||
        getHeader(headers, 'content-length') == body.contentLength.toString()) {
      return headers ?? const HttpUnmodifiableMap.empty();
    } else if (body.contentLength == 0 &&
        (headers == null || headers.isEmpty)) {
      return const HttpUnmodifiableMap.empty();
    }
  }

  var newHeaders = headers == null
      ? new CaseInsensitiveMap<String>()
      : new CaseInsensitiveMap<String>.from(headers);

  if (!sameEncoding) {
    if (newHeaders['content-type'] == null) {
      newHeaders['content-type'] =
          'application/octet-stream; charset=${body.encoding.name}';
    } else {
      var contentType = new MediaType.parse(newHeaders['content-type'])
          .change(parameters: {'charset': body.encoding.name});
      newHeaders['content-type'] = contentType.toString();
    }
  }

  if (body.contentLength != null) {
    var coding = newHeaders['transfer-encoding'];
    if (coding == null || equalsIgnoreAsciiCase(coding, 'identity')) {
      newHeaders['content-length'] = body.contentLength.toString();
    }
  }

  return newHeaders;
}

/// Returns whether [headers] declares the same encoding as [body].
bool _sameEncoding(Map<String, String> headers, Body body) {
  if (body.encoding == null) return true;

  var contentType = getHeader(headers, 'content-type');
  if (contentType == null) return false;

  var charset = new MediaType.parse(contentType).parameters['charset'];
  return Encoding.getByName(charset) == body.encoding;
}
