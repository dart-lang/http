// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';

import 'http_unmodifiable_map.dart';

/// Returns a [Map] with the values from [original] and the values from
/// [updates].
///
/// For keys that are the same between [original] and [updates], the value in
/// [updates] is used.
///
/// If [updates] is `null` or empty, [original] is returned unchanged.
Map<K, V> updateMap<K, V>(Map<K, V> original, Map<K, V> updates) {
  if (updates == null || updates.isEmpty) return original;

  return new Map<K, V>.from(original)..addAll(updates);
}

/// Converts a [Map] from parameter names to values to a URL query string.
///
///     mapToQuery({"foo": "bar", "baz": "bang"});
///     //=> "foo=bar&baz=bang"
String mapToQuery(Map<String, String> map, Encoding encoding) {
  var pairs = <List<String>>[];
  map.forEach((key, value) => pairs.add([
        Uri.encodeQueryComponent(key, encoding: encoding),
        Uri.encodeQueryComponent(value, encoding: encoding)
      ]));
  return pairs.map((pair) => "${pair[0]}=${pair[1]}").join("&");
}

/// A regular expression that matches strings that are composed entirely of
/// ASCII-compatible characters.
final RegExp _asciiOnly = new RegExp(r"^[\x00-\x7F]+$");

/// Returns whether [string] is composed entirely of ASCII-compatible
/// characters.
bool isPlainAscii(String string) => _asciiOnly.hasMatch(string);

/// Pipes all data and errors from [stream] into [sink].
///
/// Completes [Future] once [stream] is done. [sink] remains open after [stream]
/// is done.
Future writeStreamToSink(Stream stream, EventSink sink) {
  var completer = new Completer();
  stream.listen(sink.add,
      onError: sink.addError, onDone: () => completer.complete());
  return completer.future;
}

/// Returns the header with the given [name] in [headers].
///
/// This works even if [headers] is `null`, or if it's not yet a
/// case-insensitive map.
String getHeader(Map<String, String> headers, String name) {
  if (headers == null) return null;
  if (headers is HttpUnmodifiableMap) return headers[name];

  for (var key in headers.keys) {
    if (equalsIgnoreAsciiCase(key, name)) return headers[key];
  }
  return null;
}

/// Returns a [Uri] from the [url], which can be a [Uri] or a [String].
///
/// If the [url] is not a [Uri] or [String] an [ArgumentError] is thrown.
Uri getUrl(url) {
  if (url is Uri) {
    return url;
  } else if (url is String) {
    return Uri.parse(url);
  } else {
    throw new ArgumentError.value(url, 'url', 'Not a Uri or String');
  }
}
