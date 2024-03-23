// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// "token" as defined in RFC 2616, 2.2
/// See https://datatracker.ietf.org/doc/html/rfc2616#section-2.2
const _tokenChars = r"!#$%&'*+\-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ^_`"
    'abcdefghijklmnopqrstuvwxyz|~';

/// Splits comma-separated header values.
var _headerSplitter = RegExp(r'[ \t]*,[ \t]*');

/// Splits comma-separated "Set-Cookie" header values.
///
/// Set-Cookie strings can contain commas. In particular, the following
/// productions defined in RFC-6265, section 4.1.1:
/// - <sane-cookie-date> e.g. "Expires=Sun, 06 Nov 1994 08:49:37 GMT"
/// - <path-value> e.g. "Path=somepath,"
/// - <extension-av> e.g. "AnyString,Really,"
///
/// Some values are ambiguous e.g.
/// "Set-Cookie: lang=en; Path=/foo/"
/// "Set-Cookie: SID=x23"
/// and:
/// "Set-Cookie: lang=en; Path=/foo/,SID=x23"
/// would both be result in `response.headers` => "lang=en; Path=/foo/,SID=x23"
///
/// The idea behind this regex is that ",<valid token>=" is more likely to
/// start a new <cookie-pair> then be part of <path-value> or <extension-av>.
///
/// See https://datatracker.ietf.org/doc/html/rfc6265#section-4.1.1
var _setCookieSplitter = RegExp(r'[ \t]*,[ \t]*(?=[' + _tokenChars + r']+=)');

/// Splits comma-separated header values into a [List].
///
/// Copied from `package:http`.
Map<String, List<String>> splitHeaderValues(Map<String, String> headers) {
  var headersWithFieldLists = <String, List<String>>{};
  headers.forEach((key, value) {
    if (!value.contains(',')) {
      headersWithFieldLists[key] = [value];
    } else {
      if (key == 'set-cookie') {
        headersWithFieldLists[key] = value.split(_setCookieSplitter);
      } else {
        headersWithFieldLists[key] = value.split(_headerSplitter);
      }
    }
  });
  return headersWithFieldLists;
}
