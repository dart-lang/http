// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Implements a [HPackContext] for encoding/decoding headers according to the
/// HPACK specificaiton. See here for more information:
///   https://tools.ietf.org/html/draft-ietf-httpbis-header-compression-10
library http2.hpack;

import 'dart:convert';
import 'dart:io';

import 'huffman.dart';
import 'huffman_table.dart';
import '../byte_utils.dart';

/// Exception raised due to encoding/decoding errors.
class HPackDecodingException implements Exception {
  final String _message;

  HPackDecodingException(this._message);

  String toString() => 'HPackDecodingException: $_message';
}

/// A HPACK encoding/decoding context.
///
/// This is a statefull class, so encoding/decoding changes internal state.
class HPackContext {
  final HPackEncoder encoder = new HPackEncoder();
  final HPackDecoder decoder = new HPackDecoder();

  HPackContext(
      {int maxSendingHeaderTableSize: 4096,
      int maxReceivingHeaderTableSize: 4096}) {
    encoder.updateMaxSendingHeaderTableSize(maxSendingHeaderTableSize);
    decoder.updateMaxReceivingHeaderTableSize(maxReceivingHeaderTableSize);
  }
}

/// A HTTP/2 header.
class Header {
  final List<int> name;
  final List<int> value;
  final bool neverIndexed;

  Header(this.name, this.value, {this.neverIndexed: false});

  factory Header.ascii(String name, String value) {
    return new Header(ASCII.encode(name), ASCII.encode(value));
  }
}

/// A stateful HPACK decoder.
class HPackDecoder {
  int _maxHeaderTableSize;

  final IndexTable _table = new IndexTable();

  void updateMaxReceivingHeaderTableSize(int newMaximumSize) {
    _maxHeaderTableSize = newMaximumSize;
  }

  List<Header> decode(List<int> data) {
    int offset = 0;

    int readInteger(int prefixBits) {
      assert(prefixBits <= 8 && prefixBits > 0);

      var byte = data[offset++] & ((1 << prefixBits) - 1);

      int integer;
      if (byte == ((1 << prefixBits) - 1)) {
        // Length encodeded.
        integer = 0;
        int shift = 0;
        while (true) {
          bool done = (data[offset] & 0x80) != 0x80;
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
      bool isHuffmanEncoding = (data[offset] & 0x80) != 0;
      int length = readInteger(7);

      var sublist = viewOrSublist(data, offset, length);
      offset += length;
      if (isHuffmanEncoding) {
        return http2HuffmanCodec.decode(sublist);
      } else {
        return sublist;
      }
    }

    Header readHeaderFieldInternal(int index, {bool neverIndexed: false}) {
      var name, value;
      if (index > 0) {
        name = _table.lookup(index).name;
        value = readStringLiteral();
      } else {
        name = readStringLiteral();
        value = readStringLiteral();
      }
      return new Header(name, value, neverIndexed: neverIndexed);
    }

    try {
      List<Header> headers = [];
      while (offset < data.length) {
        int byte = data[offset];
        bool isIndexedField = (byte & 0x80) != 0;
        bool isIncrementalIndexing = (byte & 0xc0) == 0x40;

        bool isWithoutIndexing = (byte & 0xf0) == 0;
        bool isNeverIndexing = (byte & 0xf0) == 0x10;
        bool isDynamicTableSizeUpdate = (byte & 0xe0) == 0x20;

        if (isIndexedField) {
          int index = readInteger(7);
          var field = _table.lookup(index);
          headers.add(field);
        } else if (isIncrementalIndexing) {
          var field = readHeaderFieldInternal(readInteger(6));
          _table.addHeaderField(field);
          headers.add(field);
        } else if (isWithoutIndexing) {
          headers.add(readHeaderFieldInternal(readInteger(4)));
        } else if (isNeverIndexing) {
          headers
              .add(readHeaderFieldInternal(readInteger(4), neverIndexed: true));
        } else if (isDynamicTableSizeUpdate) {
          int newMaxSize = readInteger(5);
          if (newMaxSize <= _maxHeaderTableSize) {
            _table.updateMaxSize(newMaxSize);
          } else {
            throw new HPackDecodingException(
                'Dynamic table size update failed: '
                'A new value of $newMaxSize exceeds the limit of '
                '$_maxHeaderTableSize');
          }
        } else {
          throw new HPackDecodingException('Invalid encoding of headers.');
        }
      }
      return headers;
    } on RangeError catch (e) {
      throw new HPackDecodingException('$e');
    } on HuffmanDecodingException catch (e) {
      throw new HPackDecodingException('$e');
    }
  }
}

/// A stateful HPACK encoder.
// TODO: Currently we encode all headers:
//    - without huffman encoding
//    - without using the dynamic table
class HPackEncoder {
  int _maxHeaderTableSize = 4096;

  final IndexTable _table = new IndexTable();

  void updateMaxSendingHeaderTableSize(int newMaximumSize) {
    // TODO: Once we start encoding via dynamic table we need to let the other
    // side know the maximum table size we're using.
    _maxHeaderTableSize = newMaximumSize;
  }

  List<int> encode(List<Header> headers) {
    var bytesBuilder = new BytesBuilder();
    int currentByte = 0;

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
        bool done = false;
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
      // TODO: Support huffman encoding.
      currentByte = 0; // 1 would be huffman encoding
      writeInteger(7, bytes.length);
      bytesBuilder.add(bytes);
    }

    void writeLiteralHeaderWithoutIndexing(Header header) {
      bytesBuilder.addByte(0);
      writeStringLiteral(header.name);
      writeStringLiteral(header.value);
    }

    for (var header in headers) {
      writeLiteralHeaderWithoutIndexing(header);
    }

    return bytesBuilder.takeBytes();
  }
}

class IndexTable {
  static final List<Header> _staticTable = [
    null,
    new Header(ASCII.encode(':authority'), const []),
    new Header(ASCII.encode(':method'), ASCII.encode('GET')),
    new Header(ASCII.encode(':method'), ASCII.encode('POST')),
    new Header(ASCII.encode(':path'), ASCII.encode('/')),
    new Header(ASCII.encode(':path'), ASCII.encode('/index.html')),
    new Header(ASCII.encode(':scheme'), ASCII.encode('http')),
    new Header(ASCII.encode(':scheme'), ASCII.encode('https')),
    new Header(ASCII.encode(':status'), ASCII.encode('200')),
    new Header(ASCII.encode(':status'), ASCII.encode('204')),
    new Header(ASCII.encode(':status'), ASCII.encode('206')),
    new Header(ASCII.encode(':status'), ASCII.encode('304')),
    new Header(ASCII.encode(':status'), ASCII.encode('400')),
    new Header(ASCII.encode(':status'), ASCII.encode('404')),
    new Header(ASCII.encode(':status'), ASCII.encode('500')),
    new Header(ASCII.encode('accept-charset'), const []),
    new Header(ASCII.encode('accept-encoding'), ASCII.encode('gzip, deflate')),
    new Header(ASCII.encode('accept-language'), const []),
    new Header(ASCII.encode('accept-ranges'), const []),
    new Header(ASCII.encode('accept'), const []),
    new Header(ASCII.encode('access-control-allow-origin'), const []),
    new Header(ASCII.encode('age'), const []),
    new Header(ASCII.encode('allow'), const []),
    new Header(ASCII.encode('authorization'), const []),
    new Header(ASCII.encode('cache-control'), const []),
    new Header(ASCII.encode('content-disposition'), const []),
    new Header(ASCII.encode('content-encoding'), const []),
    new Header(ASCII.encode('content-language'), const []),
    new Header(ASCII.encode('content-length'), const []),
    new Header(ASCII.encode('content-location'), const []),
    new Header(ASCII.encode('content-range'), const []),
    new Header(ASCII.encode('content-type'), const []),
    new Header(ASCII.encode('cookie'), const []),
    new Header(ASCII.encode('date'), const []),
    new Header(ASCII.encode('etag'), const []),
    new Header(ASCII.encode('expect'), const []),
    new Header(ASCII.encode('expires'), const []),
    new Header(ASCII.encode('from'), const []),
    new Header(ASCII.encode('host'), const []),
    new Header(ASCII.encode('if-match'), const []),
    new Header(ASCII.encode('if-modified-since'), const []),
    new Header(ASCII.encode('if-none-match'), const []),
    new Header(ASCII.encode('if-range'), const []),
    new Header(ASCII.encode('if-unmodified-since'), const []),
    new Header(ASCII.encode('last-modified'), const []),
    new Header(ASCII.encode('link'), const []),
    new Header(ASCII.encode('location'), const []),
    new Header(ASCII.encode('max-forwards'), const []),
    new Header(ASCII.encode('proxy-authenticate'), const []),
    new Header(ASCII.encode('proxy-authorization'), const []),
    new Header(ASCII.encode('range'), const []),
    new Header(ASCII.encode('referer'), const []),
    new Header(ASCII.encode('refresh'), const []),
    new Header(ASCII.encode('retry-after'), const []),
    new Header(ASCII.encode('server'), const []),
    new Header(ASCII.encode('set-cookie'), const []),
    new Header(ASCII.encode('strict-transport-security'), const []),
    new Header(ASCII.encode('transfer-encoding'), const []),
    new Header(ASCII.encode('user-agent'), const []),
    new Header(ASCII.encode('vary'), const []),
    new Header(ASCII.encode('via'), const []),
    new Header(ASCII.encode('www-authenticate'), const []),
  ];

  final List<Header> _dynamicTable = [];

  /// The maximum size the dynamic table can grow to before entries need to be
  /// evicted.
  int _maximumSize = 4096;

  /// The current size of the dynamic table.
  int _currentSize = 0;

  IndexTable();

  /// Updates the maximum size which the dynamic table can grow to.
  void updateMaxSize(int newMaxDynTableSize) {
    _maximumSize = newMaxDynTableSize;
    _reduce();
  }

  /// Lookup an item by index.
  Header lookup(int index) {
    if (index <= 0) {
      throw new HPackDecodingException(
          'Invalid index (was: $index) for table lookup.');
    }
    if (index < _staticTable.length) {
      return _staticTable[index];
    }
    index -= _staticTable.length;
    if (index < _dynamicTable.length) {
      return _dynamicTable[index];
    }
    throw new HPackDecodingException(
        'Invalid index (was: $index) for table lookup.');
  }

  /// Adds a new header field to the dynamic table - and evicts entries as
  /// necessary.
  void addHeaderField(Header header) {
    _dynamicTable.insert(0, header);
    _currentSize += _sizeOf(header);
    _reduce();
  }

  /// Removes as many entries as required to be within the limit of
  /// [_maximumSize].
  void _reduce() {
    while (_currentSize > _maximumSize) {
      Header h = _dynamicTable.removeLast();
      _currentSize -= _sizeOf(h);
    }
  }

  /// Returns the "size" a [header] has.
  ///
  /// This is specified to be the number of octets of name/value plus 32.
  int _sizeOf(Header header) => header.name.length + header.value.length + 32;
}
