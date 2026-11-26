// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Implements a [HPackContext] for encoding/decoding headers according to the
/// HPACK specification. See here for more information:
///   https://tools.ietf.org/html/draft-ietf-httpbis-header-compression-10
library;

import 'dart:convert' show ascii;
import 'dart:math' show min;
import 'dart:typed_data';

import '../byte_utils.dart';
import 'huffman.dart';
import 'huffman_table.dart';

/// Exception raised due to encoding/decoding errors.
class HPackDecodingException implements Exception {
  final String _message;

  HPackDecodingException(this._message);

  @override
  String toString() => 'HPackDecodingException: $_message';
}

/// A HPACK encoding/decoding context.
///
/// This is a statefull class, so encoding/decoding changes internal state.
class HPackContext {
  final HPackEncoder encoder = HPackEncoder();
  final HPackDecoder decoder = HPackDecoder();

  HPackContext({
    int maxSendingHeaderTableSize = 4096,
    int maxReceivingHeaderTableSize = 4096,
  }) {
    encoder.updateMaxSendingHeaderTableSize(maxSendingHeaderTableSize);
    decoder.updateMaxReceivingHeaderTableSize(maxReceivingHeaderTableSize);
  }
}

/// A HTTP/2 header.
class Header {
  final List<int> name;
  final List<int> value;
  final bool neverIndexed;

  Header(this.name, this.value, {this.neverIndexed = false});

  factory Header.ascii(String name, String value) {
    // Specs: `However, header field names MUST be converted to lowercase prior
    // to their encoding in HTTP/2. A request or response containing uppercase
    // header field names MUST be treated as malformed (Section 8.1.2.6).`
    return Header(ascii.encode(name.toLowerCase()), ascii.encode(value));
  }
}

/// Result of decoding one HPACK field block with an optional field-section
/// size limit.
class HPackDecodingResult {
  final List<Header> headers;
  final int headerListSize;
  final bool headerListSizeExceeded;

  const HPackDecodingResult(
    this.headers,
    this.headerListSize,
    this.headerListSizeExceeded,
  );
}

/// A stateful HPACK decoder.
class HPackDecoder {
  late int _maxHeaderTableSize;

  final IndexTable _table = IndexTable();

  void updateMaxReceivingHeaderTableSize(int newMaximumSize) {
    _maxHeaderTableSize = newMaximumSize;
  }

  List<Header> decode(List<int> data) => decodeWithLimit(data).headers;

  /// Decodes [data] while bounding retained application-visible headers.
  ///
  /// Once [maxHeaderListSize] is exceeded, already retained headers are
  /// released and subsequent fields are parsed without being added to the
  /// result. Parsing continues so incremental-indexing updates are applied to
  /// the connection-wide dynamic table and later field blocks remain in sync.
  HPackDecodingResult decodeWithLimit(
    List<int> data, {
    int? maxHeaderListSize,
  }) {
    if (maxHeaderListSize case final limit? when limit < 0) {
      throw ArgumentError.value(limit, 'maxHeaderListSize', 'must be >= 0');
    }
    var offset = 0;

    int readInteger(int prefixBits) {
      assert(prefixBits <= 8 && prefixBits > 0);

      var byte = data[offset++] & ((1 << prefixBits) - 1);

      int integer;
      if (byte == ((1 << prefixBits) - 1)) {
        // Length encodeded.
        integer = 0;
        var shift = 0;
        while (true) {
          var done = (data[offset] & 0x80) != 0x80;
          integer += (data[offset++] & 0x7f) << shift;
          shift += 7;
          if (done) break;
        }
        integer += (1 << prefixBits) - 1;
      } else {
        // In place length.
        integer = byte;
      }

      return integer;
    }

    List<int> readStringLiteral() {
      var isHuffmanEncoding = (data[offset] & 0x80) != 0;
      var length = readInteger(7);

      var sublist = viewOrSublist(data, offset, length);
      offset += length;
      if (isHuffmanEncoding) {
        return http2HuffmanCodec.decode(sublist);
      } else {
        return sublist;
      }
    }

    Header readHeaderFieldInternal(int index, {bool neverIndexed = false}) {
      List<int> name, value;
      if (index > 0) {
        name = _table.lookup(index).name;
        value = readStringLiteral();
      } else {
        name = readStringLiteral();
        value = readStringLiteral();
      }
      return Header(name, value, neverIndexed: neverIndexed);
    }

    try {
      var headers = <Header>[];
      var headerListSize = 0;
      var headerListSizeExceeded = false;

      void processHeader(Header header) {
        headerListSize += header.name.length + header.value.length + 32;
        if (headerListSizeExceeded) return;
        if (maxHeaderListSize != null && headerListSize > maxHeaderListSize) {
          headers.clear();
          headerListSizeExceeded = true;
        } else {
          headers.add(header);
        }
      }

      while (offset < data.length) {
        var byte = data[offset];
        var isIndexedField = (byte & 0x80) != 0;
        var isIncrementalIndexing = (byte & 0xc0) == 0x40;

        var isWithoutIndexing = (byte & 0xf0) == 0;
        var isNeverIndexing = (byte & 0xf0) == 0x10;
        var isDynamicTableSizeUpdate = (byte & 0xe0) == 0x20;

        if (isIndexedField) {
          var index = readInteger(7);
          var field = _table.lookup(index);
          processHeader(field);
        } else if (isIncrementalIndexing) {
          var field = readHeaderFieldInternal(readInteger(6));
          _table.addHeaderField(field);
          processHeader(field);
        } else if (isWithoutIndexing) {
          processHeader(readHeaderFieldInternal(readInteger(4)));
        } else if (isNeverIndexing) {
          processHeader(
            readHeaderFieldInternal(readInteger(4), neverIndexed: true),
          );
        } else if (isDynamicTableSizeUpdate) {
          var newMaxSize = readInteger(5);
          if (newMaxSize <= _maxHeaderTableSize) {
            _table.updateMaxSize(newMaxSize);
          } else {
            throw HPackDecodingException(
              'Dynamic table size update failed: '
              'A new value of $newMaxSize exceeds the limit of '
              '$_maxHeaderTableSize',
            );
          }
        } else {
          throw HPackDecodingException('Invalid encoding of headers.');
        }
      }
      return HPackDecodingResult(
        headers,
        headerListSize,
        headerListSizeExceeded,
      );
      // ignore: avoid_catching_errors
    } on RangeError catch (e) {
      throw HPackDecodingException('$e');
    } on HuffmanDecodingException catch (e) {
      throw HPackDecodingException('$e');
    }
  }
}

/// A stateful HPACK encoder.
class HPackEncoder {
  /// Mirrors the peer decoder's dynamic table, so that repeated header fields
  /// are sent as an index instead of their full literal value.
  final IndexTable _table = IndexTable();

  /// The smallest table size the peer allowed since the last header block,
  /// and the latest one, which [encode] must announce before using the table
  /// again (RFC 7541 section 4.2).
  int? _pendingMinimumSize;
  int? _pendingSize;

  /// The largest dynamic table this encoder uses, whatever the peer allows:
  /// [IndexTable.find] scans it on every header field.
  static const int _maximumTableSize = 4096;

  void updateMaxSendingHeaderTableSize(int newMaximumSize) {
    final size = min(newMaximumSize, _maximumTableSize);
    if (size == _table.maximumSize && _pendingSize == null) return;
    _pendingSize = size;
    _pendingMinimumSize = min(_pendingMinimumSize ?? size, size);
    _table.updateMaxSize(size);
  }

  List<int> encode(List<Header> headers) {
    var bytesBuilder = BytesBuilder();
    var currentByte = 0;

    void writeInteger(int prefixBits, int value) {
      assert(prefixBits <= 8);

      if (value < (1 << prefixBits) - 1) {
        currentByte |= value;
        bytesBuilder.addByte(currentByte);
      } else {
        // Length encodeded.
        currentByte |= (1 << prefixBits) - 1;
        value -= (1 << prefixBits) - 1;
        bytesBuilder.addByte(currentByte);
        var done = false;
        while (!done) {
          currentByte = value & 0x7f;
          value = value >> 7;
          done = value == 0;
          if (!done) currentByte |= 0x80;
          bytesBuilder.addByte(currentByte);
        }
      }
      currentByte = 0;
    }

    void writeStringLiteral(List<int> bytes) {
      var huffman = http2HuffmanCodec.encode(bytes);
      if (huffman.length < bytes.length) {
        currentByte = 0x80;
        writeInteger(7, huffman.length);
        bytesBuilder.add(huffman);
      } else {
        currentByte = 0;
        writeInteger(7, bytes.length);
        bytesBuilder.add(bytes);
      }
    }

    void writeLiteral(
      Header header,
      int pattern,
      int prefixBits,
      int nameIndex,
    ) {
      currentByte = pattern;
      writeInteger(prefixBits, nameIndex);
      if (nameIndex == 0) writeStringLiteral(header.name);
      writeStringLiteral(header.value);
    }

    if (_pendingSize case final size?) {
      final minimum = _pendingMinimumSize!;
      if (minimum < size) {
        currentByte = 0x20;
        writeInteger(5, minimum);
      }
      currentByte = 0x20;
      writeInteger(5, size);
      _pendingSize = _pendingMinimumSize = null;
    }

    for (var header in headers) {
      final (:index, :nameIndex) = _table.find(header);
      if (index != 0) {
        // Indexed Header Field.
        currentByte = 0x80;
        writeInteger(7, index);
      } else if (header.neverIndexed || _isSensitive(header)) {
        // Literal Header Field Never Indexed.
        writeLiteral(header, 0x10, 4, nameIndex);
      } else if (IndexTable.sizeOf(header) > _table.maximumSize) {
        // Indexing it would only empty the table: Literal Header Field
        // without Indexing.
        writeLiteral(header, 0x00, 4, nameIndex);
      } else {
        // Literal Header Field with Incremental Indexing.
        writeLiteral(header, 0x40, 6, nameIndex);
        _table.addHeaderField(header);
      }
    }

    return bytesBuilder.takeBytes();
  }

  /// Whether [header] is a short credential, whose value an attacker able to
  /// inject header fields on the same connection could guess by observing how
  /// well it compresses (RFC 7541 section 7.1). Long credentials such as
  /// bearer tokens have too much entropy for that, and are indexed.
  static bool _isSensitive(Header header) =>
      header.value.length < 20 &&
      (_equals(header.name, _authorization) || _equals(header.name, _cookie));

  static final _authorization = ascii.encode('authorization');
  static final _cookie = ascii.encode('cookie');
}

bool _equals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class IndexTable {
  static final List<Header?> _staticTable = [
    null,
    Header(ascii.encode(':authority'), const []),
    Header(ascii.encode(':method'), ascii.encode('GET')),
    Header(ascii.encode(':method'), ascii.encode('POST')),
    Header(ascii.encode(':path'), ascii.encode('/')),
    Header(ascii.encode(':path'), ascii.encode('/index.html')),
    Header(ascii.encode(':scheme'), ascii.encode('http')),
    Header(ascii.encode(':scheme'), ascii.encode('https')),
    Header(ascii.encode(':status'), ascii.encode('200')),
    Header(ascii.encode(':status'), ascii.encode('204')),
    Header(ascii.encode(':status'), ascii.encode('206')),
    Header(ascii.encode(':status'), ascii.encode('304')),
    Header(ascii.encode(':status'), ascii.encode('400')),
    Header(ascii.encode(':status'), ascii.encode('404')),
    Header(ascii.encode(':status'), ascii.encode('500')),
    Header(ascii.encode('accept-charset'), const []),
    Header(ascii.encode('accept-encoding'), ascii.encode('gzip, deflate')),
    Header(ascii.encode('accept-language'), const []),
    Header(ascii.encode('accept-ranges'), const []),
    Header(ascii.encode('accept'), const []),
    Header(ascii.encode('access-control-allow-origin'), const []),
    Header(ascii.encode('age'), const []),
    Header(ascii.encode('allow'), const []),
    Header(ascii.encode('authorization'), const []),
    Header(ascii.encode('cache-control'), const []),
    Header(ascii.encode('content-disposition'), const []),
    Header(ascii.encode('content-encoding'), const []),
    Header(ascii.encode('content-language'), const []),
    Header(ascii.encode('content-length'), const []),
    Header(ascii.encode('content-location'), const []),
    Header(ascii.encode('content-range'), const []),
    Header(ascii.encode('content-type'), const []),
    Header(ascii.encode('cookie'), const []),
    Header(ascii.encode('date'), const []),
    Header(ascii.encode('etag'), const []),
    Header(ascii.encode('expect'), const []),
    Header(ascii.encode('expires'), const []),
    Header(ascii.encode('from'), const []),
    Header(ascii.encode('host'), const []),
    Header(ascii.encode('if-match'), const []),
    Header(ascii.encode('if-modified-since'), const []),
    Header(ascii.encode('if-none-match'), const []),
    Header(ascii.encode('if-range'), const []),
    Header(ascii.encode('if-unmodified-since'), const []),
    Header(ascii.encode('last-modified'), const []),
    Header(ascii.encode('link'), const []),
    Header(ascii.encode('location'), const []),
    Header(ascii.encode('max-forwards'), const []),
    Header(ascii.encode('proxy-authenticate'), const []),
    Header(ascii.encode('proxy-authorization'), const []),
    Header(ascii.encode('range'), const []),
    Header(ascii.encode('referer'), const []),
    Header(ascii.encode('refresh'), const []),
    Header(ascii.encode('retry-after'), const []),
    Header(ascii.encode('server'), const []),
    Header(ascii.encode('set-cookie'), const []),
    Header(ascii.encode('strict-transport-security'), const []),
    Header(ascii.encode('transfer-encoding'), const []),
    Header(ascii.encode('user-agent'), const []),
    Header(ascii.encode('vary'), const []),
    Header(ascii.encode('via'), const []),
    Header(ascii.encode('www-authenticate'), const []),
  ];

  final List<Header> _dynamicTable = [];

  /// The maximum size the dynamic table can grow to before entries need to be
  /// evicted.
  int _maximumSize = 4096;

  /// The current size of the dynamic table.
  int _currentSize = 0;

  IndexTable();

  /// The maximum size the dynamic table can grow to.
  int get maximumSize => _maximumSize;

  /// Updates the maximum size which the dynamic table can grow to.
  void updateMaxSize(int newMaxDynTableSize) {
    _maximumSize = newMaxDynTableSize;
    _reduce();
  }

  /// Lookup an item by index.
  Header lookup(int index) {
    if (index <= 0) {
      throw HPackDecodingException(
        'Invalid index (was: $index) for table lookup.',
      );
    }
    if (index < _staticTable.length) {
      return _staticTable[index]!;
    }
    index -= _staticTable.length;
    if (index < _dynamicTable.length) {
      return _dynamicTable[index];
    }
    throw HPackDecodingException(
      'Invalid index (was: $index) for table lookup.',
    );
  }

  /// The index of the entry equal to [header], and the index of an entry with
  /// the same name, or `0` when there is none.
  ({int index, int nameIndex}) find(Header header) {
    var nameIndex = 0;
    for (var i = 1; i < _staticTable.length; i++) {
      final entry = _staticTable[i]!;
      if (!_equals(entry.name, header.name)) continue;
      if (_equals(entry.value, header.value)) {
        return (index: i, nameIndex: i);
      }
      if (nameIndex == 0) nameIndex = i;
    }
    for (var i = 0; i < _dynamicTable.length; i++) {
      final entry = _dynamicTable[i];
      if (!_equals(entry.name, header.name)) continue;
      final index = _staticTable.length + i;
      if (_equals(entry.value, header.value)) {
        return (index: index, nameIndex: index);
      }
      if (nameIndex == 0) nameIndex = index;
    }
    return (index: 0, nameIndex: nameIndex);
  }

  /// Adds a new header field to the dynamic table - and evicts entries as
  /// necessary.
  void addHeaderField(Header header) {
    _dynamicTable.insert(0, header);
    _currentSize += sizeOf(header);
    _reduce();
  }

  /// Removes as many entries as required to be within the limit of
  /// [_maximumSize].
  void _reduce() {
    while (_currentSize > _maximumSize) {
      var h = _dynamicTable.removeLast();
      _currentSize -= sizeOf(h);
    }
  }

  /// Returns the "size" a [header] has.
  ///
  /// This is specified to be the number of octets of name/value plus 32.
  static int sizeOf(Header header) =>
      header.name.length + header.value.length + 32;
}
