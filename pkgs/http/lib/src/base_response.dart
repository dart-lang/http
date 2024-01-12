// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'base_client.dart';
import 'base_request.dart';

/// The base class for HTTP responses.
///
/// Subclasses of [BaseResponse] are usually not constructed manually; instead,
/// they're returned by [BaseClient.send] or other HTTP client methods.
abstract class BaseResponse {
  /// The (frozen) request that triggered this response.
  final BaseRequest? request;

  /// The HTTP status code for this response.
  final int statusCode;

  /// The reason phrase associated with the status code.
  final String? reasonPhrase;

  /// The size of the response body, in bytes.
  ///
  /// If the size of the request is not known in advance, this is `null`.
  final int? contentLength;

  // TODO(nweiz): automatically parse cookies from headers

  /// The HTTP headers returned by the server.
  ///
  /// The header names are converted to lowercase and stored with their
  /// associated header values.
  ///
  /// If the server returns multiple headers with the same name then the header
  /// values will be associated with a single key and seperated by commas and
  /// possibly whitespace. For example:
  /// ```dart
  /// // HTTP/1.1 200 OK
  /// // Fruit: Apple
  /// // Fruit: Banana
  /// // Fruit: Grape
  /// final values = response.headers['fruit']!.split(RegExp(r'\s*,\s*'));
  /// // values = ['Apple', 'Banana', 'Grape']
  /// ```
  ///
  /// To retrieve the header values as a `List<String>`, use
  /// [HeadersWithSplitValues.headersSplitValues].
  ///
  /// If a header value contains whitespace then that whitespace may be replaced
  /// by a single space. Leading and trailing whitespace in header values are
  /// always removed.
  final Map<String, String> headers;

  final bool isRedirect;

  /// Whether the server requested that a persistent connection be maintained.
  final bool persistentConnection;

  BaseResponse(this.statusCode,
      {this.contentLength,
      this.request,
      this.headers = const {},
      this.isRedirect = false,
      this.persistentConnection = true,
      this.reasonPhrase}) {
    if (statusCode < 100) {
      throw ArgumentError('Invalid status code $statusCode.');
    } else if (contentLength != null && contentLength! < 0) {
      throw ArgumentError('Invalid content length $contentLength.');
    }
  }
}

/// "token" as defined in RFC 2616, 2.2
/// See https://datatracker.ietf.org/doc/html/rfc2616#section-2.2
const _tokenChars = r"!#$%&'*+\-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ^_`"
    'abcdefghijklmnopqrstuvwxyz|~';

/// Splits comma-seperated header values.
var _headerSplitter = RegExp(r'[ \t]*,[ \t]*');

/// Splits comma-seperated "Set-Cookie" header values.
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

extension HeadersWithSplitValues on BaseResponse {
  /// The HTTP headers returned by the server.
  ///
  /// The header names are converted to lowercase and stored with their
  /// associated header values.
  ///
  /// Cookies can be parsed using the dart:io `Cookie` class:
  ///
  /// ```dart
  /// import "dart:io";
  /// import "package:http/http.dart";
  ///
  /// void main() async {
  /// final response = await Client().get(Uri.https('example.com', '/'));
  /// final cookies = [
  ///   for (var value i
  ///       in response.headersSplitValues['set-cookie'] ?? <String>[])
  ///     Cookie.fromSetCookieValue(value)
  /// ];
  Map<String, List<String>> get headersSplitValues {
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
}
