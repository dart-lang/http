
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import '../src/exception.dart';

import 'http_cookie.dart';
import 'http_date.dart';
import 'http_parser.dart';
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

final _digitsValidator = RegExp(r'^\d+$');
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

class CustomizedHttpHeaders extends HttpHeaders {
  final Map<String, List<String>> _headers;
  // The original header names keyed by the lowercase header names.
  Map<String, String>? _originalHeaderNames;
  final String protocolVersion;

  bool mutable = true; // Are the headers currently mutable?
  List<String>? _noFoldingHeaders;

  int _contentLength = -1;
  bool _persistentConnection = true;
  bool _chunkedTransferEncoding = false;
  String? _host;
  int? _port;

  final int _defaultPortForScheme;

  CustomizedHttpHeaders(this.protocolVersion,
      {int defaultPortForScheme = HttpClient.defaultHttpPort,
        CustomizedHttpHeaders? initialHeaders})
      : _headers = HashMap<String, List<String>>(),
        _defaultPortForScheme = defaultPortForScheme {
    if (initialHeaders != null) {
      initialHeaders._headers.forEach((name, value) => _headers[name] = value);
      _contentLength = initialHeaders._contentLength;
      _persistentConnection = initialHeaders._persistentConnection;
      _chunkedTransferEncoding = initialHeaders._chunkedTransferEncoding;
      _host = initialHeaders._host;
      _port = initialHeaders._port;
    }
    if (protocolVersion == '1.0') {
      _persistentConnection = false;
      _chunkedTransferEncoding = false;
    }
  }

  @override
  List<String>? operator [](String name) => _headers[_validateField(name)];

  @override
  String? value(String name) {
    name = _validateField(name);
    var values = _headers[name];
    if (values == null) return null;
    assert(values.isNotEmpty);
    if (values.length > 1) {
      throw HttpException('More than one value for header $name');
    }
    return values[0];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _checkMutable();
    var lowercaseName = _validateField(name);

    if (preserveHeaderCase && name != lowercaseName) {
      (_originalHeaderNames ??= {})[lowercaseName] = name;
    } else {
      _originalHeaderNames?.remove(lowercaseName);
    }
    _addAll(lowercaseName, value);
  }

  void _addAll(String name,[Object? value]) {
    if (value is Iterable) {
      for (var v in value) {
        _add(name, _validateValue(v) as String);
      }
    } else {
      _add(name, _validateValue(value) as String);
    }
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _checkMutable();
    var lowercaseName = _validateField(name);
    _headers.remove(lowercaseName);
    _originalHeaderNames?.remove(lowercaseName);
    if (lowercaseName == HttpHeaders.contentLengthHeader) {
      _contentLength = -1;
    }
    if (lowercaseName == HttpHeaders.transferEncodingHeader) {
      _chunkedTransferEncoding = false;
    }
    if (preserveHeaderCase && name != lowercaseName) {
      (_originalHeaderNames ??= {})[lowercaseName] = name;
    }
    _addAll(lowercaseName, value);
  }

  @override
  void remove(String name, Object value) {
    _checkMutable();
    name = _validateField(name);
    value = _validateValue(value)!;
    var values = _headers[name];
    if (values != null) {
      values.remove(_valueToString(value));
      if (values.isEmpty) {
        _headers.remove(name);
        _originalHeaderNames?.remove(name);
      }
    }
    if (name == HttpHeaders.transferEncodingHeader && value ==
        'chunked') {
      _chunkedTransferEncoding = false;
    }
  }

  @override
  void removeAll(String name) {
    _checkMutable();
    name = _validateField(name);
    _headers.remove(name);
    _originalHeaderNames?.remove(name);
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach((String name, List<String> values) {
      var originalName = _originalHeaderName(name);
      action(originalName, values);
    });
  }

  @override
  void noFolding(String name) {
    name = _validateField(name);
    (_noFoldingHeaders ??= <String>[]).add(name);
  }

  @override
  bool get persistentConnection => _persistentConnection;

  @override
  set persistentConnection(bool persistentConnection) {
    _checkMutable();
    if (persistentConnection == _persistentConnection) return;
    final originalName = _originalHeaderName(HttpHeaders.
    connectionHeader);
    if (persistentConnection) {
      if (protocolVersion == '1.1') {
        remove(HttpHeaders.connectionHeader, 'close');
      } else {
        if (_contentLength < 0) {
          throw const HttpException(
              "Trying to set 'Connection: Keep-Alive' on HTTP 1.0 headers with "
                  'no ContentLength');
        }
        add(originalName, 'keep-alive', preserveHeaderCase: true);
      }
    } else {
      if (protocolVersion == '1.1') {
        add(originalName, 'close', preserveHeaderCase: true);
      } else {
        remove(HttpHeaders.connectionHeader, 'keep-alive');
      }
    }
    _persistentConnection = persistentConnection;
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int contentLength) {
    _checkMutable();
    if (protocolVersion == '1.0' &&
        persistentConnection &&
        contentLength == -1) {
      throw const HttpException(
          'Trying to clear ContentLength on HTTP 1.0 headers with '
              "'Connection: Keep-Alive' set");
    }
    if (_contentLength == contentLength) return;
    _contentLength = contentLength;
    if (_contentLength >= 0) {
      if (chunkedTransferEncoding) chunkedTransferEncoding = false;
      _set(HttpHeaders.contentLengthHeader, contentLength.toString());
    } else {
      _headers.remove(HttpHeaders.contentLengthHeader);
      if (protocolVersion == '1.1') {
        chunkedTransferEncoding = true;
      }
    }
  }

  @override
  bool get chunkedTransferEncoding => _chunkedTransferEncoding;

  @override
  set chunkedTransferEncoding(bool chunkedTransferEncoding) {
    _checkMutable();
    if (chunkedTransferEncoding && protocolVersion == '1.0') {
      throw const HttpException(
          "Trying to set 'Transfer-Encoding: Chunked' on HTTP 1.0 headers");
    }
    if (chunkedTransferEncoding == _chunkedTransferEncoding) return;
    if (chunkedTransferEncoding) {
      var values = _headers[HttpHeaders.
      transferEncodingHeader];
      if (values == null || !values.contains('chunked')) {
        // Headers does not specify chunked encoding - add it if set.
        _addValue(HttpHeaders.transferEncodingHeader, 'chunked');
      }
      contentLength = -1;
    } else {
      // Headers does specify chunked encoding - remove it if not set.
      remove(HttpHeaders.transferEncodingHeader, 'chunked');
    }
    _chunkedTransferEncoding = chunkedTransferEncoding;
  }

  @override
  String? get host => _host;

  @override
  set host(String? host) {
    _checkMutable();
    _host = host;
    _updateHostHeader();
  }

  @override
  int? get port => _port;

  @override
  set port(int? port) {
    _checkMutable();
    _port = port;
    _updateHostHeader();
  }

  @override
  DateTime? get ifModifiedSince {
    var values = _headers[HttpHeaders.ifModifiedSinceHeader];
    if (values != null) {
      assert(values.isNotEmpty);
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  @override
  set ifModifiedSince(DateTime? ifModifiedSince) {
    _checkMutable();
    if (ifModifiedSince == null) {
      _headers.remove(HttpHeaders.ifModifiedSinceHeader);
    } else {
      // Format "ifModifiedSince" header with date in Greenwich Mean Time (GMT).
      var formatted = HttpDate.format(ifModifiedSince.toUtc());
      _set(HttpHeaders.ifModifiedSinceHeader, formatted);
    }
  }

  @override
  DateTime? get date {
    var values = _headers[HttpHeaders.dateHeader];
    if (values != null) {
      assert(values.isNotEmpty);
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  @override
  set date(DateTime? date) {
    _checkMutable();
    if (date == null) {
      _headers.remove(HttpHeaders.dateHeader);
    } else {
      // Format "DateTime" header with date in Greenwich Mean Time (GMT).
      var formatted = HttpDate.format(date.toUtc());
      _set(HttpHeaders.dateHeader, formatted);
    }
  }

  @override
  DateTime? get expires {
    var values = _headers[HttpHeaders.expiresHeader];
    if (values != null) {
      assert(values.isNotEmpty);
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  @override
  set expires(DateTime? expires) {
    _checkMutable();
    if (expires == null) {
      _headers.remove(HttpHeaders.expiresHeader);
    } else {
      // Format "Expires" header with date in Greenwich Mean Time (GMT).
      var formatted = HttpDate.format(expires.toUtc());
      _set(HttpHeaders.expiresHeader, formatted);
    }
  }

  @override
  ContentType? get contentType {
    var values = _headers[HttpHeaders.contentTypeHeader];
    if (values != null) {
      return ContentType.parse(values[0]);
    } else {
      return null;
    }
  }

  @override
  set contentType(ContentType? contentType) {
    _checkMutable();
    if (contentType == null) {
      _headers.remove(HttpHeaders.contentTypeHeader);
    } else {
      _set(HttpHeaders.contentTypeHeader, contentType.toString());
    }
  }

  @override
  void clear() {
    _checkMutable();
    _headers.clear();
    _contentLength = -1;
    _persistentConnection = true;
    _chunkedTransferEncoding = false;
    _host = null;
    _port = null;
  }

  // [name] must be a lower-case version of the name.
  void _add(String name, String value) {
    assert(name == _validateField(name));
    // Use the length as index on what method to call. This is notable
    // faster than computing hash and looking up in a hash-map.
    switch (name.length) {
      case 4:
        if (HttpHeaders.dateHeader == name) {
          _addDate(name, value);
          return;
        }
        if (HttpHeaders.hostHeader == name) {
          _addHost(name, value);
          return;
        }
        break;
      case 7:
        if (HttpHeaders.expiresHeader == name) {
          _addExpires(name, value);
          return;
        }
        break;
      case 10:
        if (HttpHeaders.connectionHeader == name) {
          _addConnection(name, value);
          return;
        }
        break;
      case 12:
        if (HttpHeaders.contentTypeHeader == name) {
          _addContentType(name, value);
          return;
        }
        break;
      case 14:
        if (HttpHeaders.contentLengthHeader == name) {
          _addContentLength(name, value);
          return;
        }
        break;
      case 17:
        if (HttpHeaders.transferEncodingHeader == name) {
          _addTransferEncoding(name, value);
          return;
        }
        if (HttpHeaders.ifModifiedSinceHeader == name) {
          _addIfModifiedSince(name, value);
          return;
        }
    }
    _addValue(name, value);
  }

  void _addContentLength(String name, Object? value) {
    assert(value != null);
    if (value is int) {
      if (value < 0) {
        throw const HttpException('Content-Length must contain only digits');
      }
    } else if (value is String) {
      if (!_digitsValidator.hasMatch(value)) {
        throw const HttpException('Content-Length must contain only digits');
      }
      value = int.parse(value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
    contentLength = value;
  }

  void _addTransferEncoding(String name,dynamic value) {
    if (value == 'chunked') {
      chunkedTransferEncoding = true;
    } else {
      _addValue(HttpHeaders.transferEncodingHeader, value as Object);
    }
  }

  void _addDate(String name,dynamic value) {
    if (value is DateTime) {
      date = value;
    } else if (value is String) {
      _set(HttpHeaders.dateHeader, value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
  }

  void _addExpires(String name,Object? value) {
    if (value is DateTime) {
      expires = value;
    } else if (value is String) {
      _set(HttpHeaders.expiresHeader, value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
  }

  void _addIfModifiedSince(String name,Object? value) {
    if (value is DateTime) {
      ifModifiedSince = value;
    } else if (value is String) {
      _set(HttpHeaders.ifModifiedSinceHeader, value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
  }

  void _addHost(String name,Object? value) {
    assert(value != null);
    if (value is String) {
      // value.indexOf will only work for ipv4, ipv6 which has multiple : in its
      // host part needs lastIndexOf
      var pos = value.lastIndexOf(':');
      // According to RFC 3986, section 3.2.2, host part of ipv6 address must be
      // enclosed by square brackets.
      // https://serverfault.com/questions/205793/how-can-one-distinguish-the-host-and-the-port-in-an-ipv6-url
      if (pos == -1 || value.startsWith('[') && value.endsWith(']')) {
        _host = value;
        _port = HttpClient.defaultHttpPort;
      } else {
        if (pos > 0) {
          _host = value.substring(0, pos);
        } else {
          _host = null;
        }
        if (pos + 1 == value.length) {
          _port = HttpClient.defaultHttpPort;
        } else {
          try {
            _port = int.parse(value.substring(pos + 1));
          } on FormatException {
            _port = null;
          }
        }
      }
      _set(HttpHeaders.hostHeader, value);
    } else {
      throw HttpException('Unexpected type for header named $name');
    }
  }

  void _addConnection(String name, String value) {
    var lowerCaseValue = value.toLowerCase();
    if (lowerCaseValue == 'close') {
      _persistentConnection = false;
    } else if (lowerCaseValue == 'keep-alive') {
      _persistentConnection = true;
    }
    _addValue(name, value);
  }

  void _addContentType(String name,String value) {
    _set(HttpHeaders.contentTypeHeader, value);
  }

  Object? values ;
  void _addValue(String name, Object value) {
    values = _headers[name] ??= <String>[_valueToString(value)];
  }

  String _valueToString(Object value) {
    if (value is DateTime) {
      return HttpDate.format(value);
    } else if (value is String) {
      return value; // TODO(39784): no _validateValue?
    } else {
      return _validateValue(value.toString()) as String;
    }
  }

  void _set(String name, String value) {
    assert(name == _validateField(name));
    _headers[name] = <String>[value];
  }

  void _checkMutable() {
    if (!mutable) throw const HttpException('HTTP headers are not mutable');
  }

  void _updateHostHeader() {
    var host = _host;
    if (host != null) {
      var defaultPort = _port == null || _port == _defaultPortForScheme;
      _set('host', defaultPort ? host : '$host:$_port');
    }
  }

  bool _foldHeader(String name) {
    if (name == HttpHeaders.setCookieHeader) return false;
    var noFoldingHeaders = _noFoldingHeaders;
    return noFoldingHeaders == null || !noFoldingHeaders.contains(name);
  }

  void _finalize() {
    mutable = false;
  }

  void _build(BytesBuilder builder, {bool skipZeroContentLength = false}) {
    // per https://tools.ietf.org/html/rfc7230#section-3.3.2
    // A user agent SHOULD NOT send a
    // Content-Length header field when the request message does not
    // contain a payload body and the method semantics do not anticipate
    // such a body.
    var ignoreHeader = _contentLength == 0 && skipZeroContentLength
        ? HttpHeaders.contentLengthHeader
        : null;
    _headers.forEach((String name, List<String> values) {
      if (ignoreHeader == name) {
        return;
      }
      var originalName = _originalHeaderName(name);
      var fold = _foldHeader(name);
      var nameData = originalName.codeUnits;
      builder..add(nameData)
      ..addByte(CharCode.COLON)
      ..addByte(CharCode.SP);
      for (var i = 0; i < values.length; i++) {
        if (i > 0) {
          if (fold) {
            builder..addByte(CharCode.COMMA)
              ..addByte(CharCode.SP);
          } else {
            builder..addByte(CharCode.CR)
            ..addByte(CharCode.LF)
            ..add(nameData)
            ..addByte(CharCode.COLON)
            ..addByte(CharCode.SP);
          }
        }
        builder.add(values[i].codeUnits);
      }
      builder..addByte(CharCode.CR)
      ..addByte(CharCode.LF);
    });
  }

  @override
  String toString() {
    var sb = StringBuffer();
    _headers.forEach((String name, List<String> values) {
      var originalName = _originalHeaderName(name);
      sb
        ..write(originalName)
        ..write(': ');
      var fold = _foldHeader(name);
      for (var i = 0; i < values.length; i++) {
        if (i > 0) {
          if (fold) {
            sb.write(', ');
          } else {
            sb
              ..write('\n')
              ..write(originalName)
              ..write(': ');
          }
        }
        sb.write(values[i]);
      }
      sb.write('\n');
    });
    return sb.toString();
  }

  List<Cookie> _parseCookies() {
    // Parse a Cookie header value according to the rules in RFC 6265.
    var cookies = <Cookie>[];
    void parseCookieString(String s) {
      var index = 0;

      bool done() => index == -1 || index == s.length;

      void skipWS() {
        while (!done()) {
          if (s[index] != ' ' && s[index] != '\t') return;
          index++;
        }
      }

      String parseName() {
        var start = index;
        while (!done()) {
          if (s[index] == ' ' || s[index] == '\t' || s[index] == '=') break;
          index++;
        }
        return s.substring(start, index);
      }

      String parseValue() {
        var start = index;
        while (!done()) {
          if (s[index] == ' ' || s[index] == '\t' || s[index] == ';') break;
          index++;
        }
        return s.substring(start, index);
      }

      bool expect(String expected) {
        if (done()) return false;
        if (s[index] != expected) return false;
        index++;
        return true;
      }

      while (!done()) {
        skipWS();
        if (done()) return;
        var name = parseName();
        skipWS();
        if (!expect('=')) {
          index = s.indexOf(';', index);
          continue;
        }
        skipWS();
        var value = parseValue();
        try {
          cookies.add(Cookie(name, value));
        } catch (_) {
          // Skip it, invalid cookie data.
        }
        skipWS();
        if (done()) return;
        if (!expect(';')) {
          index = s.indexOf(';', index);
          continue;
        }
      }
    }

    var values = _headers[HttpHeaders.cookieHeader];
    if (values != null) {
      for (var headerValue in values) {
        parseCookieString(headerValue);
      }
    }
    return cookies;
  }

  static String _validateField(String field) {
    for (var i = 0; i < field.length; i++) {
      if (!HttpParser.isTokenChar(field.codeUnitAt(i))) {
        throw FormatException(
            'Invalid HTTP header field name: ${json.encode(field)}', field, i);
      }
    }
    return field.toLowerCase();
  }

  static Object? _validateValue(Object? value) {
    if (value is! String) return value;
    for (var i = 0; i < value.length; i++) {
      if (!HttpParser.isValueChar(value.codeUnitAt(i))) {
        throw FormatException(
            'Invalid HTTP header field value: ${json.encode(value)}', value, i);
      }
    }
    return value;
  }

  String _originalHeaderName(String name) =>
      _originalHeaderNames?[name] ?? name;
}

/// A MIME/IANA media type used as the value of the
/// [HttpHeaders.contentTypeHeader] header.
///
/// A [ContentType] is immutable.
class _HeaderValue {
  String _value;
  Map<String, String?>? _parameters;
  Map<String, String?>? _unmodifiableParameters;

  _HeaderValue([this._value = '', Map<String, String?> parameters = const {}]) {
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
                sb..write(value.substring(start, i))
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

  static _HeaderValue parse(String value,
      {String parameterSeparator = ';',
        String? valueSeparator,
        bool preserveBackslash = false}) {
    // Parse the string.
    var val = parse(value,
        parameterSeparator:parameterSeparator,
        valueSeparator:valueSeparator,
        preserveBackslash:preserveBackslash);
    return val;
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
      {String? charset, Map<String, String?> parameters = const {}})
  => _ContentType(primaryType, subType, charset, parameters);

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
        super('') {
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
      result.._primaryType =
          result._value.substring(0, index).trim().toLowerCase()
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