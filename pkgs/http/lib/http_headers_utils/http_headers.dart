import 'dart:collection';
import 'dart:io';

import '../src/exception.dart';

import 'sdk_annotations.dart';

/// Headers for HTTP requests and responses.
///
/// In some situations, headers are immutable:
///
/// * [HttpRequest] and [HttpClientResponse] always have immutable headers.
///
/// * [HttpResponse] and [HttpClientRequest] have immutable headers
///   from the moment the body is written to.
///
/// In these situations, the mutating methods throw exceptions.
///
/// For all operations on HTTP headers the header name is
/// case-insensitive.
///
/// To set the value of a header use the `set()` method:
///
///     request.headers.set(HttpHeaders.cacheControlHeader,
///                         'max-age=3600, must-revalidate');
///
/// To retrieve the value of a header use the `value()` method:
///
///     print(request.headers.value(HttpHeaders.userAgentHeader));
///
/// An `HttpHeaders` object holds a list of values for each name
/// as the standard allows. In most cases a name holds only a single value,
/// The most common mode of operation is to use `set()` for setting a value,
/// and `value()` for retrieving a value.

abstract class HttpHeaders {
  static const acceptHeader = 'accept';
  static const acceptCharsetHeader = 'accept-charset';
  static const acceptEncodingHeader = 'accept-encoding';
  static const acceptLanguageHeader = 'accept-language';
  static const acceptRangesHeader = 'accept-ranges';
  @Since('2.14')
  static const accessControlAllowCredentialsHeader =
      'access-control-allow-credentials';
  @Since('2.14')
  static const accessControlAllowHeadersHeader = 'access-control-allow-headers';
  @Since('2.14')
  static const accessControlAllowMethodsHeader = 'access-control-allow-methods';
  @Since('2.14')
  static const accessControlAllowOriginHeader = 'access-control-allow-origin';
  @Since('2.14')
  static const accessControlExposeHeadersHeader =
      'access-control-expose-headers';
  @Since('2.14')
  static const accessControlMaxAgeHeader = 'access-control-max-age';
  @Since('2.14')
  static const accessControlRequestHeadersHeader =
      'access-control-request-headers';
  @Since('2.14')
  static const accessControlRequestMethodHeader =
      'access-control-request-method';
  static const ageHeader = 'age';
  static const allowHeader = 'allow';
  static const authorizationHeader = 'authorization';
  static const cacheControlHeader = 'cache-control';
  static const connectionHeader = 'connection';
  static const contentEncodingHeader = 'content-encoding';
  static const contentLanguageHeader = 'content-language';
  static const contentLengthHeader = 'content-length';
  static const contentLocationHeader = 'content-location';
  static const contentMD5Header = 'content-md5';
  static const contentRangeHeader = 'content-range';
  static const contentTypeHeader = 'content-type';
  static const dateHeader = 'date';
  static const etagHeader = 'etag';
  static const expectHeader = 'expect';
  static const expiresHeader = 'expires';
  static const fromHeader = 'from';
  static const hostHeader = 'host';
  static const ifMatchHeader = 'if-match';
  static const ifModifiedSinceHeader = 'if-modified-since';
  static const ifNoneMatchHeader = 'if-none-match';
  static const ifRangeHeader = 'if-range';
  static const ifUnmodifiedSinceHeader = 'if-unmodified-since';
  static const lastModifiedHeader = 'last-modified';
  static const locationHeader = 'location';
  static const maxForwardsHeader = 'max-forwards';
  static const pragmaHeader = 'pragma';
  static const proxyAuthenticateHeader = 'proxy-authenticate';
  static const proxyAuthorizationHeader = 'proxy-authorization';
  static const rangeHeader = 'range';
  static const refererHeader = 'referer';
  static const retryAfterHeader = 'retry-after';
  static const serverHeader = 'server';
  static const teHeader = 'te';
  static const trailerHeader = 'trailer';
  static const transferEncodingHeader = 'transfer-encoding';
  static const upgradeHeader = 'upgrade';
  static const userAgentHeader = 'user-agent';
  static const varyHeader = 'vary';
  static const viaHeader = 'via';
  static const warningHeader = 'warning';
  static const wwwAuthenticateHeader = 'www-authenticate';

  // Cookie headers from RFC 6265.
  static const cookieHeader = 'cookie';
  static const setCookieHeader = 'set-cookie';

  // TODO(39783): Document this.
  static const generalHeaders = [
    cacheControlHeader,
    connectionHeader,
    dateHeader,
    pragmaHeader,
    trailerHeader,
    transferEncodingHeader,
    upgradeHeader,
    viaHeader,
    warningHeader
  ];

  static const entityHeaders = [
    allowHeader,
    contentEncodingHeader,
    contentLanguageHeader,
    contentLengthHeader,
    contentLocationHeader,
    contentMD5Header,
    contentRangeHeader,
    contentTypeHeader,
    expiresHeader,
    lastModifiedHeader
  ];

  static const responseHeaders = [
    acceptRangesHeader,
    ageHeader,
    etagHeader,
    locationHeader,
    proxyAuthenticateHeader,
    retryAfterHeader,
    serverHeader,
    varyHeader,
    wwwAuthenticateHeader
  ];

  static const requestHeaders = [
    acceptHeader,
    acceptCharsetHeader,
    acceptEncodingHeader,
    acceptLanguageHeader,
    authorizationHeader,
    expectHeader,
    fromHeader,
    hostHeader,
    ifMatchHeader,
    ifModifiedSinceHeader,
    ifNoneMatchHeader,
    ifRangeHeader,
    ifUnmodifiedSinceHeader,
    maxForwardsHeader,
    proxyAuthorizationHeader,
    rangeHeader,
    refererHeader,
    teHeader,
    userAgentHeader
  ];

  /// The date specified by the [dateHeader] header, if any.
  DateTime? date;

  /// The date and time specified by the [expiresHeader] header, if any.
  DateTime? expires;

  /// The date and time specified by the [ifModifiedSinceHeader] header, if any.
  DateTime? ifModifiedSince;

  /// The value of the [hostHeader] header, if any.
  String? host;

  /// The value of the port part of the [hostHeader] header, if any.
  int? port;

  /// The [ContentType] of the [contentTypeHeader] header, if any.
  ContentType? contentType;

  /// The value of the [contentLengthHeader] header, if any.
  ///
  /// The value is negative if there is no content length set.
  int contentLength = -1;

  /// Whether the connection is persistent (keep-alive).
  late bool persistentConnection;

  /// Whether the connection uses chunked transfer encoding.
  ///
  /// Reflects and modifies the value of the [transferEncodingHeader] header.
  late bool chunkedTransferEncoding;

  /// The values for the header named [name].
  ///
  /// Returns null if there is no header with the provided name,
  /// otherwise returns a new list containing the current values.
  /// Not that modifying the list does not change the header.
  List<String>? operator [](String name);

  /// Convenience method for the value for a single valued header.
  ///
  /// The value must not have more than one value.
  ///
  /// Returns `null` if there is no header with the provided name.
  String? value(String name);

  /// Adds a header value.
  ///
  /// The header named [name] will have a string value derived from [value]
  /// added to its list of values.
  ///
  /// Some headers are single valued, and for these, adding a value will
  /// replace a previous value. If the [value] is a [DateTime], an
  /// HTTP date format will be applied. If the value is an [Iterable],
  /// each element will be added separately. For all other
  /// types the default [Object.toString] method will be used.
  ///
  /// Header names are converted to lower-case unless
  /// [preserveHeaderCase] is set to true. If two header names are
  /// the same when converted to lower-case, they are considered to be
  /// the same header, with one set of values.
  ///
  /// The current case of the a header name is that of the name used by
  /// the last [set] or [add] call for that header.
  void add(String name, Object value,
      {@Since('2.8') bool preserveHeaderCase = false});

  /// Sets the header [name] to [value].
  ///
  /// Removes all existing values for the header named [name] and
  /// then [add]s [value] to it.
  void set(String name, Object value,
      {@Since('2.8') bool preserveHeaderCase = false});

  /// Removes a specific value for a header name.
  ///
  /// Some headers have system supplied values which cannot be removed.
  /// For all other headers and values, the [value] is converted to a string
  /// in the same way as for [add], then that string value is removed from the
  /// current values of [name].
  /// If there are no remaining values for [name], the header is no longer
  /// considered present.
  void remove(String name, Object value);

  /// Removes all values for the specified header name.
  ///
  /// Some headers have system supplied values which cannot be removed.
  /// All other values for [name] are removed.
  /// If there are no remaining values for [name], the header is no longer
  /// considered present.
  void removeAll(String name);

  /// Performs the [action] on each header.
  ///
  /// The [action] function is called with each header's name and a list
  /// of the header's values. The casing of the name string is determined by
  /// the last [add] or [set] operation for that particular header,
  /// which defaults to lower-casing the header name unless explicitly
  /// set to preserve the case.
  void forEach(void Function(String name, List<String> values) action);

  /// Disables folding for the header named [name] when sending the HTTP header.
  ///
  /// By default, multiple header values are folded into a
  /// single header line by separating the values with commas.
  ///
  /// The 'set-cookie' header has folding disabled by default.
  void noFolding(String name);

  /// Removes all headers.
  ///
  /// Some headers have system supplied values which cannot be removed.
  /// All other header values are removed, and header names with not
  /// remaining values are no longer considered present.
  void clear();
}

/// A MIME/IANA media type used as the value of the
/// [HttpHeaders.contentTypeHeader] header.
///
/// A [ContentType] is immutable.
class _HeaderValue {
  late String _value;
  Map<String, String?>? _parameters;
  Map<String, String?>? _unmodifiableParameters;

  _HeaderValue([Map<String, String?> parameters = const {}]) {
    // TODO(40614): Remove once non-nullability is sound.
    Map<String, String?>? nullableParameters = parameters;
    if (nullableParameters.isNotEmpty) {
      _parameters = HashMap<String, String?>.from(nullableParameters);
    }
  }

  String get value => _value;

  Map<String, String?> _ensureParameters() =>
      _parameters ??= <String, String?>{};

  Map<String, String?> get parameters =>
      _unmodifiableParameters ??= UnmodifiableMapView(_ensureParameters());

  static bool _isToken(String token) {
    if (token.isEmpty) {
      return false;
    }
    const delimiters = '"(),/:;<=>?@[]{}';
    for (var i = 0; i < token.length; i++) {
      var codeUnit = token.codeUnitAt(i);
      if (codeUnit <= 32 || codeUnit >= 127 || delimiters.contains(token[i])) {
        return false;
      }
    }
    return true;
  }

  StringBuffer sb = StringBuffer();

  @override
  String toString() {
    sb.write(_value);
    var parameters = _parameters;
    if (parameters != null && parameters.isNotEmpty) {
      parameters.forEach((String name, String? value) {
        sb
          ..write('; ')
          ..write(name);
        if (value != null) {
          sb.write('=');
          if (_isToken(value)) {
            sb.write(value);
          } else {
            sb.write('"');
            var start = 0;
            for (var i = 0; i < value.length; i++) {
              // Can use codeUnitAt here instead.
              var codeUnit = value.codeUnitAt(i);
              if (codeUnit == 92 /* backslash */ ||
                  codeUnit == 34 /* double quote */) {
                sb
                  ..write(value.substring(start, i))
                  ..write(r'\');
                start = i;
              }
            }
            sb
              ..write(value.substring(start))
              ..write('"');
          }
        }
      });
    }
    return sb.toString();
  }

  void _parse(String s, String parameterSeparator, String? valueSeparator,
      bool preserveBackslash) {
    var index = 0;

    bool done() => index == s.length;

    void skipWS() {
      while (!done()) {
        if (s[index] != ' ' && s[index] != '\t') return;
        index++;
      }
    }

    String parseValue() {
      var start = index;
      while (!done()) {
        var char = s[index];
        if (char == ' ' ||
            char == '\t' ||
            char == valueSeparator ||
            char == parameterSeparator) break;
        index++;
      }
      return s.substring(start, index);
    }

    void expect(String expected) {
      if (done() || s[index] != expected) {
        throw const HttpException('Failed to parse header value');
      }
      index++;
    }

    bool maybeExpect(String expected) {
      if (done() || !s.startsWith(expected, index)) {
        return false;
      }
      index++;
      return true;
    }

    void parseParameters() {
      var parameters = _ensureParameters();

      String parseParameterName() {
        var start = index;
        while (!done()) {
          var char = s[index];
          if (char == '' ||
              char == '\t' ||
              char == '=' ||
              char == parameterSeparator ||
              char == valueSeparator) break;
          index++;
        }
        return s.substring(start, index).toLowerCase();
      }

      String parseParameterValue() {
        if (!done() && s[index] == '"') {
          // Parse quoted value.
          var sb = StringBuffer();
          index++;
          while (!done()) {
            var char = s[index];
            if (char == '\\') {
              if (index + 1 == s.length) {
                throw const HttpException('Failed to parse header value');
              }
              if (preserveBackslash && s[index + 1] != '"') {
                sb.write(char);
              }
              index++;
            } else if (char == '"') {
              index++;
              return sb.toString();
            }
            char = s[index];
            sb.write(char);
            index++;
          }
          throw const HttpException('Failed to parse header value');
        } else {
          // Parse non-quoted value.
          return parseValue();
        }
      }

      while (!done()) {
        skipWS();
        if (done()) return;
        var name = parseParameterName();
        skipWS();
        if (maybeExpect('=')) {
          skipWS();
          var value = parseParameterValue();
          if (name == 'charset' && this is _ContentType) {
            // Charset parameter of ContentTypes are always lower-case.
            value = value.toLowerCase();
          }
          parameters[name] = value;
          skipWS();
        } else if (name.isNotEmpty) {
          parameters[name] = null;
        }
        if (done()) return;
        // TODO: Implement support for multi-valued parameters.
        if (s[index] == valueSeparator) return;
        expect(parameterSeparator);
      }
    }

    skipWS();
    _value = parseValue();
    skipWS();
    if (done()) return;
    if (s[index] == valueSeparator) return;
    maybeExpect(parameterSeparator);
    parseParameters();
  }
}

/// A MIME/IANA media type used as the value of the
/// [HttpHeaders.contentTypeHeader] header.
///
/// A [ContentType] is immutable.
abstract class ContentType implements _HeaderValue {
  /// Content type for plain text using UTF-8 encoding.
  ///
  ///     text/plain; charset=utf-8
  static final text = ContentType('text', 'plain', charset: 'utf-8');

  /// Content type for HTML using UTF-8 encoding.
  ///
  ///    text/html; charset=utf-8
  static final html = ContentType('text', 'html', charset: 'utf-8');

  /// Content type for JSON using UTF-8 encoding.
  ///
  ///    application/json; charset=utf-8
  static final json = ContentType('application', 'json', charset: 'utf-8');

  /// Content type for binary data.
  ///
  ///    application/octet-stream
  static final binary = ContentType('application', 'octet-stream');

  /// Creates a new content type object setting the primary type and
  /// sub type. The charset and additional parameters can also be set
  /// using [charset] and [parameters]. If charset is passed and
  /// [parameters] contains charset as well the passed [charset] will
  /// override the value in parameters. Keys passed in parameters will be
  /// converted to lower case. The `charset` entry, whether passed as `charset`
  /// or in `parameters`, will have its value converted to lower-case.
  factory ContentType(String primaryType, String subType,
          {String? charset, Map<String, String?> parameters = const {}}) =>
      _ContentType(primaryType, subType, charset, parameters);

  /// Creates a new content type object from parsing a Content-Type
  /// header value. As primary type, sub type and parameter names and
  /// values are not case sensitive all these values will be converted
  /// to lower case. Parsing this string
  ///
  ///     text/html; charset=utf-8
  ///
  /// will create a content type object with primary type 'text",
  /// subtype "html" and parameter "charset" with value "utf-8".
  /// There may be more parameters supplied, but they are not recognized
  /// by this class.
  static ContentType parse(String value) => _ContentType.parse(value);

  /// Gets the MIME type and subtype, without any parameters.
  ///
  /// For the full content type `text/html;charset=utf-8`,
  /// the [mimeType] value is the string `text/html`.
  String get mimeType;

  /// Gets the primary type.
  ///
  /// For the full content type `text/html;charset=utf-8`,
  /// the [primaryType] value is the string `text`.
  String get primaryType;

  /// Gets the subtype.
  ///
  /// For the full content type `text/html;charset=utf-8`,
  /// the [subType] value is the string `html`.
  /// May be the empty string.
  String get subType;

  /// Gets the character set, if any.
  ///
  /// For the full content type `text/html;charset=utf-8`,
  /// the [charset] value is the string `utf-8`.
  String? get charset;
}

class _ContentType extends _HeaderValue implements ContentType {
  String _primaryType = '';
  String _subType = '';

  _ContentType(String primaryType, String subType, String? charset,
      Map<String, String?> parameters)
      : _primaryType = primaryType,
        _subType = subType,
        super() {
    // TODO(40614): Remove once non-nullability is sound.
    String emptyIfNull(String? string) => string ?? '';
    _primaryType = emptyIfNull(_primaryType);
    _subType = emptyIfNull(_subType);
    _value = '$_primaryType/$_subType';
    // TODO(40614): Remove once non-nullability is sound.
    Map<String, String?>? nullableParameters = parameters;
    var parameterMap = _ensureParameters();
    nullableParameters.forEach((String key, String? value) {
      var lowerCaseKey = key.toLowerCase();
      if (lowerCaseKey == 'charset') {
        value = value?.toLowerCase();
      }
      parameterMap[lowerCaseKey] = value;
    });
    if (charset != null) {
      _ensureParameters()['charset'] = charset.toLowerCase();
    }
  }

  _ContentType._();

  static _ContentType parse(String value) {
    var result = _ContentType._().._parse(value, ';', null, false);
    var index = result._value.indexOf('/');
    if (index == -1 || index == (result._value.length - 1)) {
      result._primaryType = result._value.trim().toLowerCase();
    } else {
      result
        .._primaryType = result._value.substring(0, index).trim().toLowerCase()
        .._subType = result._value.substring(index + 1).trim().toLowerCase();
    }
    return result;
  }

  @override
  String get mimeType => '$primaryType/$subType';
  @override
  String get primaryType => _primaryType;
  @override
  String get subType => _subType;

  @override
  String? get charset => parameters['charset'];
}
