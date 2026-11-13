// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../transport.dart';

/// Validated metadata extracted from an inbound HTTP/2 field block.
class ValidatedHeaderBlock {
  final bool hasPseudoHeaders;
  final bool isInformationalResponse;
  final bool isHeadRequest;
  final int? statusCode;
  final int? contentLength;

  const ValidatedHeaderBlock({
    required this.hasPseudoHeaders,
    required this.isInformationalResponse,
    required this.isHeadRequest,
    this.statusCode,
    this.contentLength,
  });
}

/// Validates an inbound decoded HTTP/2 field section against RFC 9113
/// Sections 8.1, 8.2.1, 8.2.2, 8.3, and 8.5.
///
/// Returns a [ValidatedHeaderBlock] if valid, or an error description string if
/// the message is malformed and must be rejected with a stream error of type
/// `PROTOCOL_ERROR` (RFC 9113 Section 8.1.1).
(ValidatedHeaderBlock?, String?) validateInboundHeaderBlock(
  List<Header> headers, {
  required bool isRequest,
  required bool isTrailer,
}) {
  var sawRegularHeader = false;
  var hasPseudoHeaders = false;

  String? method;
  String? scheme;
  String? authority;
  String? path;
  String? protocol;
  int? statusCode;
  int? contentLength;

  for (final header in headers) {
    final nameBytes = header.name;
    final valueBytes = header.value;
    if (nameBytes.isEmpty) {
      return (null, 'Header field name must not be empty.');
    }
    if (!_isValidFieldValue(valueBytes)) {
      return (null, 'Header field value contains invalid octets or padding.');
    }

    if (nameBytes[0] == 0x3a /* ':' */ ) {
      if (isTrailer) {
        return (null, 'Pseudo-header fields are not allowed in trailers.');
      }
      if (sawRegularHeader) {
        return (
          null,
          'Pseudo-header fields must precede regular header fields.',
        );
      }
      if (nameBytes.length == 1 || !_areLowercaseTchars(nameBytes, start: 1)) {
        return (null, 'Invalid pseudo-header field name.');
      }
      hasPseudoHeaders = true;
      final name = String.fromCharCodes(nameBytes);
      if (isRequest) {
        switch (name) {
          case ':method':
            if (method != null) {
              return (null, 'Duplicate :method pseudo-header.');
            }
            if (valueBytes.isEmpty || !_areTokenChars(valueBytes)) {
              return (null, 'Invalid :method pseudo-header value.');
            }
            method = String.fromCharCodes(valueBytes);
          case ':scheme':
            if (scheme != null) {
              return (null, 'Duplicate :scheme pseudo-header.');
            }
            if (valueBytes.isEmpty) {
              return (null, 'Empty :scheme pseudo-header value.');
            }
            scheme = String.fromCharCodes(valueBytes);
          case ':authority':
            if (authority != null) {
              return (null, 'Duplicate :authority pseudo-header.');
            }
            authority = String.fromCharCodes(valueBytes);
          case ':path':
            if (path != null) {
              return (null, 'Duplicate :path pseudo-header.');
            }
            path = String.fromCharCodes(valueBytes);
          case ':protocol':
            if (protocol != null) {
              return (null, 'Duplicate :protocol pseudo-header.');
            }
            if (valueBytes.isEmpty) {
              return (null, 'Empty :protocol pseudo-header value.');
            }
            protocol = String.fromCharCodes(valueBytes);
          default:
            return (null, 'Unknown request pseudo-header "$name".');
        }
      } else {
        if (name != ':status') {
          return (null, 'Unknown response pseudo-header "$name".');
        }
        if (statusCode != null) {
          return (null, 'Duplicate :status pseudo-header.');
        }
        final parsed = _parseThreeDigitStatus(valueBytes);
        // RFC 9113 section 8.6: HTTP/2 does not support 101 (Switching
        // Protocols).
        if (parsed == null || parsed < 100 || parsed > 599 || parsed == 101) {
          return (null, 'Invalid :status pseudo-header value.');
        }
        statusCode = parsed;
      }
    } else {
      sawRegularHeader = true;
      if (!_areLowercaseTchars(nameBytes)) {
        return (
          null,
          'Header field name contains uppercase or invalid characters.',
        );
      }

      // Check connection-specific and framing headers (RFC 9113 section 8.2.2
      // and section 8.1.1) with length guards so common headers do not
      // allocate strings.
      switch (nameBytes.length) {
        case 2:
          if (nameBytes[0] == 0x74 && nameBytes[1] == 0x65 /* 'te' */ ) {
            if (!_asciiEquals(valueBytes, 'trailers')) {
              return (
                null,
                'The "te" header field must only have the value "trailers".',
              );
            }
          }
        case 7:
          if (_asciiEquals(nameBytes, 'upgrade')) {
            return (null, 'Forbidden connection-specific header "upgrade".');
          }
        case 10:
          if (_asciiEquals(nameBytes, 'connection') ||
              _asciiEquals(nameBytes, 'keep-alive')) {
            return (null, 'Forbidden connection-specific header.');
          }
        case 14:
          if (_asciiEquals(nameBytes, 'content-length')) {
            if (isTrailer) {
              return (
                null,
                'The "content-length" header is not allowed in trailers.',
              );
            }
            final parsed = _parseNonNegativeDigits(valueBytes);
            if (parsed == null) {
              return (null, 'Invalid "content-length" header value.');
            }
            if (contentLength != null && contentLength != parsed) {
              return (null, 'Conflicting "content-length" header values.');
            }
            contentLength = parsed;
          }
        case 16:
          if (_asciiEquals(nameBytes, 'proxy-connection')) {
            return (
              null,
              'Forbidden connection-specific header "proxy-connection".',
            );
          }
        case 17:
          if (_asciiEquals(nameBytes, 'transfer-encoding')) {
            return (
              null,
              'Forbidden connection-specific header "transfer-encoding".',
            );
          }
      }
    }
  }

  if (isRequest && !isTrailer) {
    if (method == 'CONNECT' && protocol == null) {
      // RFC 9113 section 8.5: standard CONNECT requests carry :method and
      // :authority, and omit :scheme and :path.
      if (scheme != null ||
          path != null ||
          authority == null ||
          authority.isEmpty) {
        return (null, 'Malformed CONNECT request pseudo-headers.');
      }
    } else {
      if (path != null && path.isEmpty) {
        return (null, 'The :path pseudo-header must not be empty.');
      }
      if ((method != null || scheme != null || protocol != null) &&
          (method == null || scheme == null || path == null || path.isEmpty)) {
        return (null, 'Missing mandatory request pseudo-header.');
      }
    }
  }

  final isInformational =
      statusCode != null && statusCode >= 100 && statusCode < 200;
  return (
    ValidatedHeaderBlock(
      hasPseudoHeaders: hasPseudoHeaders,
      isInformationalResponse: isInformational,
      isHeadRequest: method == 'HEAD',
      statusCode: statusCode,
      contentLength: contentLength,
    ),
    null,
  );
}

/// Whether [headers] sets `:method` to `HEAD`.
bool isHeadRequestHeaders(List<Header> headers) {
  for (final header in headers) {
    if (_asciiEquals(header.name, ':method')) {
      return _asciiEquals(header.value, 'HEAD');
    }
  }
  return false;
}

bool _isValidFieldValue(List<int> bytes) {
  if (bytes.isEmpty) return true;
  final first = bytes.first;
  final last = bytes.last;
  // RFC 9113 section 8.2.1: field values must not start or end with SP or HTAB.
  if (first == 0x20 || first == 0x09 || last == 0x20 || last == 0x09) {
    return false;
  }
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    // Reject NUL (0x00), LF (0x0a), CR (0x0d), DEL (0x7f), and other CTLs
    // except internal HTAB (0x09) and SP (0x20..0x7e, 0x80..0xff).
    if ((b < 0x20 && b != 0x09) || b == 0x7f || b > 0xff) {
      return false;
    }
  }
  return true;
}

bool _areLowercaseTchars(List<int> bytes, {int start = 0}) {
  for (var i = start; i < bytes.length; i++) {
    if (!_isLowercaseTchar(bytes[i])) return false;
  }
  return true;
}

bool _areTokenChars(List<int> bytes) {
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    if (!_isLowercaseTchar(b) && !(b >= 0x41 && b <= 0x5a)) {
      return false;
    }
  }
  return true;
}

bool _isLowercaseTchar(int b) {
  if ((b >= 0x61 && b <= 0x7a) || (b >= 0x30 && b <= 0x39)) return true;
  return switch (b) {
    0x21 || // !
    0x23 || // #
    0x24 || // $
    0x25 || // %
    0x26 || // &
    0x27 || // '
    0x2a || // *
    0x2b || // +
    0x2d || // -
    0x2e || // .
    0x5e || // ^
    0x5f || // _
    0x60 || // `
    0x7c || // |
    0x7e => // ~
    true,
    _ => false,
  };
}

bool _asciiEquals(List<int> bytes, String asciiLiteral) {
  if (bytes.length != asciiLiteral.length) return false;
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] != asciiLiteral.codeUnitAt(i)) return false;
  }
  return true;
}

int? _parseThreeDigitStatus(List<int> bytes) {
  if (bytes.length != 3) return null;
  final d0 = bytes[0] - 0x30;
  final d1 = bytes[1] - 0x30;
  final d2 = bytes[2] - 0x30;
  if (d0 < 0 || d0 > 9 || d1 < 0 || d1 > 9 || d2 < 0 || d2 > 9) return null;
  return d0 * 100 + d1 * 10 + d2;
}

int? _parseNonNegativeDigits(List<int> bytes) {
  if (bytes.isEmpty) return null;
  var value = 0;
  for (var i = 0; i < bytes.length; i++) {
    final d = bytes[i] - 0x30;
    if (d < 0 || d > 9) return null;
    if (value > (0x7fffffffffffffff - d) ~/ 10) return null;
    value = value * 10 + d;
  }
  return value;
}
