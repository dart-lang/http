// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';

import 'byte_stream.dart';

/// Converts a [Map] from parameter names to values to a URL query string.
///
///     mapToQuery({"foo": "bar", "baz": "bang"});
///     //=> "foo=bar&baz=bang"
String mapToQuery(Map<String, String> map, {required Encoding encoding}) =>
    map.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key, encoding: encoding)}'
            '=${Uri.encodeQueryComponent(e.value, encoding: encoding)}')
        .join('&');

/// Determines the appropriate [Encoding] based on the given [contentTypeHeader]
///
/// - If the `Content-Type` is `application/json` and no charset is specified,
///   it defaults to [utf8].
/// - If a charset is specified in the parameters,
///   it attempts to find a matching [Encoding].
/// - If no charset is specified or the charset is unknown,
///   it falls back to the provided [fallback], which defaults to [latin1].
Encoding encodingForContentTypeHeader(MediaType contentTypeHeader,
    [Encoding fallback = latin1]) {
  final charset = contentTypeHeader.parameters['charset'];

  // Default to utf8 for application/json when charset is unspecified.
  if (contentTypeHeader.type == 'application' &&
      contentTypeHeader.subtype == 'json' &&
      charset == null) {
    return utf8;
  }

  // Attempt to find the encoding or fall back to the default.
  return charset != null ? Encoding.getByName(charset) ?? fallback : fallback;
}

/// Returns the [Encoding] that corresponds to [charset].
///
/// Throws a [FormatException] if no [Encoding] was found that corresponds to
/// [charset].
Encoding requiredEncodingForCharset(String charset) =>
    Encoding.getByName(charset) ??
    (throw FormatException('Unsupported encoding "$charset".'));

/// A regular expression that matches strings that are composed entirely of
/// ASCII-compatible characters.
final _asciiOnly = RegExp(r'^[\x00-\x7F]+$');

/// Returns whether [string] is composed entirely of ASCII-compatible
/// characters.
bool isPlainAscii(String string) => _asciiOnly.hasMatch(string);

/// Converts [input] into a [Uint8List].
///
/// If [input] is a [TypedData], this just returns a view on [input].
Uint8List toUint8List(List<int> input) {
  if (input is Uint8List) return input;
  if (input case TypedData data) {
    return Uint8List.view(data.buffer);
  }
  return Uint8List.fromList(input);
}

ByteStream toByteStream(Stream<List<int>> stream) {
  if (stream is ByteStream) return stream;
  return ByteStream(stream);
}

/// Calls [onDone] once [stream] (a single-subscription [Stream]) is finished.
///
/// The return value, also a single-subscription [Stream] should be used in
/// place of [stream] after calling this method.
Stream<T> onDone<T>(Stream<T> stream, void Function() onDone) =>
    stream.transform(StreamTransformer.fromHandlers(handleDone: (sink) {
      sink.close();
      onDone();
    }));
