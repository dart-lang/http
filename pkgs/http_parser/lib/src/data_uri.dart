// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:string_scanner/string_scanner.dart';

import 'media_type.dart';
import 'scan.dart';
import 'utils.dart';

/// Like [whitespace] from scan.dart, except that it matches URI-encoded
/// whitespace rather than literal characters.
final _whitespace = new RegExp(r'(?:(?:%0D%0A)?(?:%20|%09)+)*');

/// A converter for percent encoding strings using UTF-8.
final _utf8Percent = UTF8.fuse(percent);

/// A class representing a `data:` URI that provides access to its [mediaType]
/// and the [data] it contains.
///
/// Data can be encoded as a `data:` URI using [encode] or [encodeString], and
/// decoded using [decode].
///
/// This implementation is based on [RFC 2397][rfc], but as that RFC is
/// [notoriously ambiguous][ambiguities], some judgment calls have been made.
/// This class tries to match browsers' data URI logic, to ensure that it can
/// losslessly parse its own output, and to accept as much input as it can make
/// sense of. A balance has been struck between these goals so that while none
/// of them have been accomplished perfectly, all of them are close enough for
/// practical use.
///
/// [rfc]: http://tools.ietf.org/html/rfc2397
/// [ambiguities]: https://simonsapin.github.io/data-urls/
///
/// Some particular notes on the behavior:
///
/// * When encoding, all characters that are not [reserved][] in the type,
///   subtype, parameter names, and parameter values of media types are
///   percent-encoded using UTF-8.
///
/// * When decoding, the type, subtype, parameter names, and parameter values of
///   media types are percent-decoded using UTF-8. Parameter values are allowed
///   to contain non-token characters once decoded, but the other tokens are
///   not.
///
/// * As per the spec, quoted-string parameters are not supported when decoding.
///
/// * Query components are included in the decoding algorithm, but fragments are
///   not.
///
/// * Invalid media types and parameters will raise exceptions when decoding.
///   This is standard for Dart parsers but contrary to browser behavior.
///
/// * The URL and filename-safe base64 alphabet is accepted when decoding but
///   never emitted when encoding, since browsers don't support it.
///
/// [lws]: https://tools.ietf.org/html/rfc2616#section-2.2
/// [reserved]: https://tools.ietf.org/html/rfc3986#section-2.2
class DataUri implements Uri {
  /// The inner URI to which all [Uri] methods are forwarded.
  final Uri _inner;

  /// The byte data contained in the data URI.
  final List<int> data;

  /// The media type declared for the data URI.
  ///
  /// This defaults to `text/plain;charset=US-ASCII`.
  final MediaType mediaType;

  /// The encoding declared by the `charset` parameter in [mediaType].
  ///
  /// If [mediaType] has no `charset` parameter, this defaults to [ASCII]. If
  /// the `charset` parameter declares an encoding that can't be found using
  /// [Encoding.getByName], this returns `null`.
  Encoding get declaredEncoding {
    var charset = mediaType.parameters["charset"];
    return charset == null ? ASCII : Encoding.getByName(charset);
  }

  /// Creates a new data URI with the given [mediaType] and [data].
  ///
  /// If [base64] is `true` (the default), the data is base64-encoded;
  /// otherwise, it's percent-encoded.
  ///
  /// If [encoding] is passed or [mediaType] declares a `charset` parameter,
  /// [data] is encoded using that encoding. Otherwise, it's encoded using
  /// [UTF8] or [ASCII] depending on whether it contains any non-ASCII
  /// characters.
  ///
  /// Throws [ArgumentError] if [mediaType] and [encoding] disagree on the
  /// encoding, and an [UnsupportedError] if [mediaType] defines an encoding
  /// that's not supported by [Encoding.getByName].
  factory DataUri.encodeString(String data, {bool base64: true,
      MediaType mediaType, Encoding encoding}) {
    if (mediaType == null) mediaType = new MediaType("text", "plain");

    var charset = mediaType.parameters["charset"];
    var bytes;
    if (encoding != null) {
      if (charset == null) {
        mediaType = mediaType.change(parameters: {"charset": encoding.name});
      } else if (Encoding.getByName(charset) != encoding) {
        throw new ArgumentError("Media type charset '$charset' disagrees with "
            "encoding '${encoding.name}'.");
      }
      bytes = encoding.encode(data);
    } else if (charset != null) {
      encoding = Encoding.getByName(charset);
      if (encoding == null) {
        throw new UnsupportedError(
            'Unsupported media type charset "$charset".');
      }
      bytes = encoding.encode(data);
    } else if (data.codeUnits.every((codeUnit) => codeUnit < 0x80)) {
      // If the data is pure ASCII, don't bother explicitly defining a charset.
      bytes = data.codeUnits;
    } else {
      // If the data isn't pure ASCII, default to UTF-8.
      bytes = UTF8.encode(data);
      mediaType = mediaType.change(parameters: {"charset": "utf-8"});
    }

    return new DataUri.encode(bytes, base64: base64, mediaType: mediaType);
  }

  /// Creates a new data URI with the given [mediaType] and [data].
  ///
  /// If [base64] is `true` (the default), the data is base64-encoded;
  /// otherwise, it's percent-encoded.
  factory DataUri.encode(List<int> data, {bool base64: true,
      MediaType mediaType}) {
    mediaType ??= new MediaType('text', 'plain');

    var buffer = new StringBuffer();

    // Manually stringify the media type because [section 3][rfc] requires that
    // parameter values should have non-token characters URL-escaped rather than
    // emitting them as quoted-strings. This also allows us to omit text/plain
    // if possible.
    //
    // [rfc]: http://tools.ietf.org/html/rfc2397#section-3
    if (mediaType.type != 'text' || mediaType.subtype != 'plain') {
      buffer.write(_utf8Percent.encode(mediaType.type));
      buffer.write("/");
      buffer.write(_utf8Percent.encode(mediaType.subtype));
    }

    mediaType.parameters.forEach((attribute, value) {
      buffer.write(";${_utf8Percent.encode(attribute)}=");
      buffer.write(_utf8Percent.encode(value));
    });

    if (base64) {
      buffer.write(";base64,");
      // *Don't* use the URL-safe encoding scheme, since browsers don't actually
      // support it.
      buffer.write(CryptoUtils.bytesToBase64(data));
    } else {
      buffer.write(",");
      buffer.write(percent.encode(data));
    }

    return new DataUri._(data, mediaType,
        new Uri(scheme: 'data', path: buffer.toString()));
  }

  /// Decodes [uri] to make its [data] and [mediaType] available.
  ///
  /// [uri] may be a [Uri] or a [String].
  ///
  /// Throws an [ArgumentError] if [uri] is an invalid type or has a scheme
  /// other than `data:`. Throws a [FormatException] if parsing fails.
  factory DataUri.decode(uri) {
    if (uri is String) {
      uri = Uri.parse(uri);
    } else if (uri is! Uri) {
      throw new ArgumentError.value(uri, "uri", "Must be a String or a Uri.");
    }

    if (uri.scheme != 'data') {
      throw new ArgumentError.value(uri, "uri", "Can only decode a data: URI.");
    }

    return wrapFormatException("data URI", uri.toString(), () {
      // Remove the fragment, as per https://simonsapin.github.io/data-urls/.
      // TODO(nweiz): Use Uri.removeFragment once sdk#24593 is fixed.
      var string = uri.toString();
      var fragment = string.indexOf('#');
      if (fragment != -1) string = string.substring(0, fragment);
      var scanner = new StringScanner(string);
      scanner.expect('data:');

      // Manually scan the media type for three reasons:
      //
      // * Media type parameter values that aren't valid tokens are URL-encoded
      //   rather than quoted.
      //
      // * The media type may be omitted without omitting the parameters.
      //
      // * We need to be able to stop once we reach `;base64,`, even though at
      //   first it looks like a parameter.
      var type;
      var subtype;
      var implicitType = false;
      if (scanner.scan(token)) {
        type = _verifyToken(scanner);
        scanner.expect('/');
        subtype = _expectToken(scanner);
      } else {
        type = 'text';
        subtype = 'plain';
        implicitType = true;
      }

      // Scan the parameters, up through ";base64" or a comma.
      var parameters = {};
      var base64 = false;
      while (scanner.scan(';')) {
        var attribute = _expectToken(scanner);

        if (attribute != 'base64') {
          scanner.expect('=');
        } else if (!scanner.scan('=')) {
          base64 = true;
          break;
        }

        // Don't use [_expectToken] because the value uses percent-encoding to
        // escape non-token characters.
        scanner.expect(token);
        parameters[attribute] = _utf8Percent.decode(scanner.lastMatch[0]);
      }
      scanner.expect(',');

      if (implicitType && parameters.isEmpty) {
        parameters = {"charset": "US-ASCII"};
      }

      var mediaType = new MediaType(type, subtype, parameters);

      var data = base64
          ? CryptoUtils.base64StringToBytes(scanner.rest)
          : percent.decode(scanner.rest);

      return new DataUri._(data, mediaType, uri);
    });
  }

  /// Returns the percent-decoded value of the last MIME token scanned by
  /// [scanner].
  ///
  /// Throws a [FormatException] if it's not a valid token after
  /// percent-decoding.
  static String _verifyToken(StringScanner scanner) {
    var value = _utf8Percent.decode(scanner.lastMatch[0]);
    if (!value.contains(nonToken)) return value;
    scanner.error("Invalid token.");
    return null;
  }

  /// Scans [scanner] through a MIME token and returns its percent-decoded
  /// value.
  ///
  /// Throws a [FormatException] if it's not a valid token after
  /// percent-decoding.
  static String _expectToken(StringScanner scanner) {
    scanner.expect(token, name: "a token");
    return _verifyToken(scanner);
  }

  DataUri._(this.data, this.mediaType, this._inner);

  /// Returns the decoded [data] decoded using [encoding].
  ///
  /// [encoding] defaults to [declaredEncoding]. If the declared encoding isn't
  /// supported by [Encoding.getByName] and [encoding] isn't passed, this throws
  /// an [UnsupportedError].
  String dataAsString({Encoding encoding}) {
    encoding ??= declaredEncoding;
    if (encoding == null) {
      throw new UnsupportedError(
          'Unsupported media type charset '
          '"${mediaType.parameters["charset"]}".');
    }

    return encoding.decode(data);
  }

  String get scheme => _inner.scheme;
  String get authority => _inner.authority;
  String get userInfo => _inner.userInfo;
  String get host => _inner.host;
  int get port => _inner.port;
  String get path => _inner.path;
  String get query => _inner.query;
  String get fragment => _inner.fragment;
  Uri replace({String scheme, String userInfo, String host, int port,
          String path, Iterable<String> pathSegments, String query,
          Map<String, String> queryParameters, String fragment}) =>
      _inner.replace(
          scheme: scheme, userInfo: userInfo, host: host, port: port,
          path: path, pathSegments: pathSegments, query: query,
          queryParameters: queryParameters, fragment: fragment);
  Uri removeFragment() => _inner.removeFragment();
  List<String> get pathSegments => _inner.pathSegments;
  Map<String, String> get queryParameters => _inner.queryParameters;
  Uri normalizePath() => _inner.normalizePath();
  bool get isAbsolute => _inner.isAbsolute;
  Uri resolve(String reference) => _inner.resolve(reference);
  Uri resolveUri(Uri reference) => _inner.resolveUri(reference);
  bool get hasScheme => _inner.hasScheme;
  bool get hasAuthority => _inner.hasAuthority;
  bool get hasPort => _inner.hasPort;
  bool get hasQuery => _inner.hasQuery;
  bool get hasFragment => _inner.hasFragment;
  bool get hasEmptyPath => _inner.hasEmptyPath;
  bool get hasAbsolutePath => _inner.hasAbsolutePath;
  String get origin => _inner.origin;
  String toFilePath({bool windows}) => _inner.toFilePath(windows: windows);
  String toString() => _inner.toString();
  bool operator==(other) => _inner == other;
  int get hashCode => _inner.hashCode;
}
