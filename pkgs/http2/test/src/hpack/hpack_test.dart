// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:http2/src/hpack/hpack.dart';

void main() {
  group('hpack', () {
    group('hpack-spec-decoder', () {
      test('C.3 request without huffman encoding', () {
        var context = HPackContext();
        List<Header> headers;

        // First request
        headers = context.decoder.decode([
          0x82,
          0x86,
          0x84,
          0x41,
          0x0f,
          0x77,
          0x77,
          0x77,
          0x2e,
          0x65,
          0x78,
          0x61,
          0x6d,
          0x70,
          0x6c,
          0x65,
          0x2e,
          0x63,
          0x6f,
          0x6d
        ]);
        expect(headers, hasLength(4));
        expect(headers[0], isHeader(':method', 'GET'));
        expect(headers[1], isHeader(':scheme', 'http'));
        expect(headers[2], isHeader(':path', '/'));
        expect(headers[3], isHeader(':authority', 'www.example.com'));

        // Second request
        headers = context.decoder.decode([
          0x82,
          0x86,
          0x84,
          0xbe,
          0x58,
          0x08,
          0x6e,
          0x6f,
          0x2d,
          0x63,
          0x61,
          0x63,
          0x68,
          0x65
        ]);
        expect(headers, hasLength(5));
        expect(headers[0], isHeader(':method', 'GET'));
        expect(headers[1], isHeader(':scheme', 'http'));
        expect(headers[2], isHeader(':path', '/'));
        expect(headers[3], isHeader(':authority', 'www.example.com'));
        expect(headers[4], isHeader('cache-control', 'no-cache'));

        // Third request
        headers = context.decoder.decode([
          0x82,
          0x87,
          0x85,
          0xbf,
          0x40,
          0x0a,
          0x63,
          0x75,
          0x73,
          0x74,
          0x6f,
          0x6d,
          0x2d,
          0x6b,
          0x65,
          0x79,
          0x0c,
          0x63,
          0x75,
          0x73,
          0x74,
          0x6f,
          0x6d,
          0x2d,
          0x76,
          0x61,
          0x6c,
          0x75,
          0x65
        ]);
        expect(headers, hasLength(5));
        expect(headers[0], isHeader(':method', 'GET'));
        expect(headers[1], isHeader(':scheme', 'https'));
        expect(headers[2], isHeader(':path', '/index.html'));
        expect(headers[3], isHeader(':authority', 'www.example.com'));
        expect(headers[4], isHeader('custom-key', 'custom-value'));
      });

      test('C.4 request with huffman encoding', () {
        var context = HPackContext();
        List<Header> headers;

        // First request
        headers = context.decoder.decode([
          0x82,
          0x86,
          0x84,
          0x41,
          0x8c,
          0xf1,
          0xe3,
          0xc2,
          0xe5,
          0xf2,
          0x3a,
          0x6b,
          0xa0,
          0xab,
          0x90,
          0xf4,
          0xff
        ]);
        expect(headers, hasLength(4));
        expect(headers[0], isHeader(':method', 'GET'));
        expect(headers[1], isHeader(':scheme', 'http'));
        expect(headers[2], isHeader(':path', '/'));
        expect(headers[3], isHeader(':authority', 'www.example.com'));

        // Second request
        headers = context.decoder.decode([
          0x82,
          0x86,
          0x84,
          0xbe,
          0x58,
          0x86,
          0xa8,
          0xeb,
          0x10,
          0x64,
          0x9c,
          0xbf
        ]);
        expect(headers, hasLength(5));
        expect(headers[0], isHeader(':method', 'GET'));
        expect(headers[1], isHeader(':scheme', 'http'));
        expect(headers[2], isHeader(':path', '/'));
        expect(headers[3], isHeader(':authority', 'www.example.com'));
        expect(headers[4], isHeader('cache-control', 'no-cache'));

        // Third request
        headers = context.decoder.decode([
          0x82,
          0x87,
          0x85,
          0xbf,
          0x40,
          0x88,
          0x25,
          0xa8,
          0x49,
          0xe9,
          0x5b,
          0xa9,
          0x7d,
          0x7f,
          0x89,
          0x25,
          0xa8,
          0x49,
          0xe9,
          0x5b,
          0xb8,
          0xe8,
          0xb4,
          0xbf
        ]);
        expect(headers, hasLength(5));
        expect(headers[0], isHeader(':method', 'GET'));
        expect(headers[1], isHeader(':scheme', 'https'));
        expect(headers[2], isHeader(':path', '/index.html'));
        expect(headers[3], isHeader(':authority', 'www.example.com'));
        expect(headers[4], isHeader('custom-key', 'custom-value'));
      });

      test('C.5 response without huffman encoding', () {
        var context = HPackContext();
        List<Header> headers;

        // First response
        headers = context.decoder.decode([
          0x48,
          0x03,
          0x33,
          0x30,
          0x32,
          0x58,
          0x07,
          0x70,
          0x72,
          0x69,
          0x76,
          0x61,
          0x74,
          0x65,
          0x61,
          0x1d,
          0x4d,
          0x6f,
          0x6e,
          0x2c,
          0x20,
          0x32,
          0x31,
          0x20,
          0x4f,
          0x63,
          0x74,
          0x20,
          0x32,
          0x30,
          0x31,
          0x33,
          0x20,
          0x32,
          0x30,
          0x3a,
          0x31,
          0x33,
          0x3a,
          0x32,
          0x31,
          0x20,
          0x47,
          0x4d,
          0x54,
          0x6e,
          0x17,
          0x68,
          0x74,
          0x74,
          0x70,
          0x73,
          0x3a,
          0x2f,
          0x2f,
          0x77,
          0x77,
          0x77,
          0x2e,
          0x65,
          0x78,
          0x61,
          0x6d,
          0x70,
          0x6c,
          0x65,
          0x2e,
          0x63,
          0x6f,
          0x6d
        ]);
        expect(headers, hasLength(4));
        expect(headers[0], isHeader(':status', '302'));
        expect(headers[1], isHeader('cache-control', 'private'));
        expect(headers[2], isHeader('date', 'Mon, 21 Oct 2013 20:13:21 GMT'));
        expect(headers[3], isHeader('location', 'https://www.example.com'));

        // Second response
        headers = context.decoder
            .decode([0x48, 0x03, 0x33, 0x30, 0x37, 0xc1, 0xc0, 0xbf]);
        expect(headers, hasLength(4));
        expect(headers[0], isHeader(':status', '307'));
        expect(headers[1], isHeader('cache-control', 'private'));
        expect(headers[2], isHeader('date', 'Mon, 21 Oct 2013 20:13:21 GMT'));
        expect(headers[3], isHeader('location', 'https://www.example.com'));

        // Third response
        headers = context.decoder.decode([
          0x88,
          0xc1,
          0x61,
          0x1d,
          0x4d,
          0x6f,
          0x6e,
          0x2c,
          0x20,
          0x32,
          0x31,
          0x20,
          0x4f,
          0x63,
          0x74,
          0x20,
          0x32,
          0x30,
          0x31,
          0x33,
          0x20,
          0x32,
          0x30,
          0x3a,
          0x31,
          0x33,
          0x3a,
          0x32,
          0x32,
          0x20,
          0x47,
          0x4d,
          0x54,
          0xc0,
          0x5a,
          0x04,
          0x67,
          0x7a,
          0x69,
          0x70,
          0x77,
          0x38,
          0x66,
          0x6f,
          0x6f,
          0x3d,
          0x41,
          0x53,
          0x44,
          0x4a,
          0x4b,
          0x48,
          0x51,
          0x4b,
          0x42,
          0x5a,
          0x58,
          0x4f,
          0x51,
          0x57,
          0x45,
          0x4f,
          0x50,
          0x49,
          0x55,
          0x41,
          0x58,
          0x51,
          0x57,
          0x45,
          0x4f,
          0x49,
          0x55,
          0x3b,
          0x20,
          0x6d,
          0x61,
          0x78,
          0x2d,
          0x61,
          0x67,
          0x65,
          0x3d,
          0x33,
          0x36,
          0x30,
          0x30,
          0x3b,
          0x20,
          0x76,
          0x65,
          0x72,
          0x73,
          0x69,
          0x6f,
          0x6e,
          0x3d,
          0x31
        ]);
        expect(headers, hasLength(6));
        expect(headers[0], isHeader(':status', '200'));
        expect(headers[1], isHeader('cache-control', 'private'));
        expect(headers[2], isHeader('date', 'Mon, 21 Oct 2013 20:13:22 GMT'));
        expect(headers[3], isHeader('location', 'https://www.example.com'));
        expect(headers[4], isHeader('content-encoding', 'gzip'));
        expect(
            headers[5],
            isHeader('set-cookie',
                'foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1'));
      });

      test('C.6 response with huffman encoding', () {
        var context = HPackContext();
        List<Header> headers;

        // First response
        headers = context.decoder.decode([
          0x48,
          0x82,
          0x64,
          0x02,
          0x58,
          0x85,
          0xae,
          0xc3,
          0x77,
          0x1a,
          0x4b,
          0x61,
          0x96,
          0xd0,
          0x7a,
          0xbe,
          0x94,
          0x10,
          0x54,
          0xd4,
          0x44,
          0xa8,
          0x20,
          0x05,
          0x95,
          0x04,
          0x0b,
          0x81,
          0x66,
          0xe0,
          0x82,
          0xa6,
          0x2d,
          0x1b,
          0xff,
          0x6e,
          0x91,
          0x9d,
          0x29,
          0xad,
          0x17,
          0x18,
          0x63,
          0xc7,
          0x8f,
          0x0b,
          0x97,
          0xc8,
          0xe9,
          0xae,
          0x82,
          0xae,
          0x43,
          0xd3
        ]);
        expect(headers, hasLength(4));
        expect(headers[0], isHeader(':status', '302'));
        expect(headers[1], isHeader('cache-control', 'private'));
        expect(headers[2], isHeader('date', 'Mon, 21 Oct 2013 20:13:21 GMT'));
        expect(headers[3], isHeader('location', 'https://www.example.com'));

        // Second response
        headers = context.decoder
            .decode([0x48, 0x83, 0x64, 0x0e, 0xff, 0xc1, 0xc0, 0xbf]);
        expect(headers, hasLength(4));
        expect(headers[0], isHeader(':status', '307'));
        expect(headers[1], isHeader('cache-control', 'private'));
        expect(headers[2], isHeader('date', 'Mon, 21 Oct 2013 20:13:21 GMT'));
        expect(headers[3], isHeader('location', 'https://www.example.com'));

        // Third response
        headers = context.decoder.decode([
          0x88,
          0xc1,
          0x61,
          0x96,
          0xd0,
          0x7a,
          0xbe,
          0x94,
          0x10,
          0x54,
          0xd4,
          0x44,
          0xa8,
          0x20,
          0x05,
          0x95,
          0x04,
          0x0b,
          0x81,
          0x66,
          0xe0,
          0x84,
          0xa6,
          0x2d,
          0x1b,
          0xff,
          0xc0,
          0x5a,
          0x83,
          0x9b,
          0xd9,
          0xab,
          0x77,
          0xad,
          0x94,
          0xe7,
          0x82,
          0x1d,
          0xd7,
          0xf2,
          0xe6,
          0xc7,
          0xb3,
          0x35,
          0xdf,
          0xdf,
          0xcd,
          0x5b,
          0x39,
          0x60,
          0xd5,
          0xaf,
          0x27,
          0x08,
          0x7f,
          0x36,
          0x72,
          0xc1,
          0xab,
          0x27,
          0x0f,
          0xb5,
          0x29,
          0x1f,
          0x95,
          0x87,
          0x31,
          0x60,
          0x65,
          0xc0,
          0x03,
          0xed,
          0x4e,
          0xe5,
          0xb1,
          0x06,
          0x3d,
          0x50,
          0x07
        ]);
        expect(headers, hasLength(6));
        expect(headers[0], isHeader(':status', '200'));
        expect(headers[1], isHeader('cache-control', 'private'));
        expect(headers[2], isHeader('date', 'Mon, 21 Oct 2013 20:13:22 GMT'));
        expect(headers[3], isHeader('location', 'https://www.example.com'));
        expect(headers[4], isHeader('content-encoding', 'gzip'));
        expect(
            headers[5],
            isHeader('set-cookie',
                'foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1'));
      });
    });

    group('negative-decoder-tests', () {
      test('invalid-integer-encoding', () {
        var context = HPackContext();
        expect(() => context.decoder.decode([1 << 6, 0xff]),
            throwsA(isHPackDecodingException));
      });

      test('index-out-of-table-size', () {
        var context = HPackContext();
        expect(() => context.decoder.decode([0x7f]),
            throwsA(isHPackDecodingException));
      });

      test('invalid-update-dynamic-table-size', () {
        var context = HPackContext();
        expect(() => context.decoder.decode([0x3f]),
            throwsA(isHPackDecodingException));
      });

      test('update-dynamic-table-size-too-high', () {
        var context = HPackContext();
        // Tries to set dynamic table to 4097 (max is 4096 by default)
        var bytes = TestHelper.newInteger(0x20, 5, 4097);
        expect(() => context.decoder.decode(bytes),
            throwsA(isHPackDecodingException));
      });
    });

    group('custom decoder tests', () {
      const char0 = 0x30;
      const char1 = 0x31;
      const char2 = 0x31;
      const char3 = 0x31;
      const charA = 0x61;
      const charB = 0x62;
      const charC = 0x63;
      const charD = 0x64;

      test('update-dynamic-table-size-too-high', () {
        var context = HPackContext();
        // Sets dynamic table to 4096
        expect(
            context.decoder.decode(TestHelper.newInteger(0x20, 5, 4096)), []);
      });

      test('dynamic table entry', () {
        List<Header> headers;
        var context = HPackContext();

        var buffer = <int>[];
        buffer.addAll(TestHelper.insertIntoDynamicTable(2048, char0, charA));
        buffer.addAll(TestHelper.insertIntoDynamicTable(2048, char1, charB));
        buffer.addAll(TestHelper.dynamicTableLookup(0));
        buffer.addAll(TestHelper.dynamicTableLookup(1));
        buffer.addAll(TestHelper.dynamicTableLookup(0));
        buffer.addAll(TestHelper.dynamicTableLookup(1));
        buffer.addAll(TestHelper.insertIntoDynamicTable(1024, char2, charC));
        buffer.addAll(TestHelper.insertIntoDynamicTable(1024, char3, charD));
        buffer.addAll(TestHelper.dynamicTableLookup(0));
        buffer.addAll(TestHelper.dynamicTableLookup(1));
        buffer.addAll(TestHelper.dynamicTableLookup(2));

        headers = context.decoder.decode(buffer);
        expect(headers, hasLength(11));
        TestHelper.expectHeader(headers[0], 2048, char0, charA);
        TestHelper.expectHeader(headers[1], 2048, char1, charB);

        TestHelper.expectHeader(headers[2], 2048, char1, charB);
        TestHelper.expectHeader(headers[3], 2048, char0, charA);
        TestHelper.expectHeader(headers[4], 2048, char1, charB);
        TestHelper.expectHeader(headers[5], 2048, char0, charA);

        TestHelper.expectHeader(headers[6], 1024, char2, charC);
        TestHelper.expectHeader(headers[7], 1024, char3, charD);

        TestHelper.expectHeader(headers[8], 1024, char1, charD);
        TestHelper.expectHeader(headers[9], 1024, char0, charC);
        TestHelper.expectHeader(headers[10], 2048, char1, charB);

        // We're reducing now the size by 1 byte, which should evict the last
        // entry.
        headers =
            context.decoder.decode(TestHelper.setDynamicTableSize(4096 - 1));
        expect(headers, hasLength(0));

        headers = context.decoder.decode(TestHelper.dynamicTableLookup(0));
        expect(headers, hasLength(1));
        TestHelper.expectHeader(headers[0], 1024, char1, charD);

        headers = context.decoder.decode(TestHelper.dynamicTableLookup(1));
        expect(headers, hasLength(1));
        TestHelper.expectHeader(headers[0], 1024, char0, charC);

        // Since we reduce the size by 1 byte, the last entry must be gone now.
        expect(() => context.decoder.decode(TestHelper.dynamicTableLookup(2)),
            throwsA(isHPackDecodingException));
      });
    });

    group('encoder-tests', () {
      test('simple-encoding', () {
        var context = HPackContext();
        var headers = [Header.ascii('key', 'value')];
        expect(context.encoder.encode(headers),
            [0x00, 0x03, 0x6b, 0x65, 0x79, 0x05, 0x76, 0x61, 0x6c, 0x75, 0x65]);
      });

      test('simple-encoding-long-value', () {
        var context = HPackContext();
        var headers = [
          Header([0x42], List.filled(300, 0x84))
        ];

        expect(context.decoder.decode(context.encoder.encode(headers)).first,
            equalsHeader(headers.first));

        expect(context.encoder.encode(headers), [
          // Literal Header Field with Incremental Indexing - Indexed Name
          0x00,

          // Key: Length
          0x01,

          // Key: Bytes
          0x42,

          // Value: (first 7 bits + rest)
          0x7f, 0xad, 0x01,

          // Value: Bytes
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,

          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,

          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
          0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84, 0x84,
        ]);
      });
    });
  });
}

class TestHelper {
  static List<int> setDynamicTableSize(int newSize) {
    return TestHelper.newInteger(0x20, 5, newSize);
  }

  static List<int> newInteger(int currentByte, int prefixBits, int value) {
    assert((currentByte & ((1 << prefixBits) - 1)) == 0);
    var buffer = <int>[];
    if (value < ((1 << prefixBits) - 1)) {
      currentByte |= value;
      buffer.add(currentByte);
    } else {
      // Length encodeded.
      currentByte |= (1 << prefixBits) - 1;
      value -= (1 << prefixBits) - 1;
      buffer.add(currentByte);
      var done = false;
      while (!done) {
        currentByte = value & 0x7f;
        value = value >> 7;
        done = value == 0;
        if (!done) currentByte |= 0x80;
        buffer.add(currentByte);
      }
    }
    return buffer;
  }

  static List<int> insertIntoDynamicTable(int n, int nameChar, int valueChar) {
    // NOTE: size(header) = 32 + header.name.length + header.value.length.

    var buffer = <int>[];

    // Literal indexed (will be put into dynamic table)
    buffer.addAll([0x40]);

    var name = [nameChar];
    buffer.addAll(newInteger(0, 7, name.length));
    buffer.addAll(name);

    var value = List.filled(n - 32 - name.length, valueChar);
    buffer.addAll(newInteger(0, 7, value.length));
    buffer.addAll(value);

    return buffer;
  }

  static List<int> dynamicTableLookup(int index) {
    // There are 62 entries in the static table.
    return newInteger(0x80, 7, 62 + index);
  }

  static void expectHeader(Header h, int len, int nameChar, int valueChar) {
    var data = h.value;
    expect(data, hasLength(len - 32 - 1));
    for (var i = 0; i < data.length; i++) {
      expect(data[i], valueChar);
    }
  }
}

/// A matcher for HuffmannDecodingExceptions.
const Matcher isHPackDecodingException = TypeMatcher<HPackDecodingException>();

class _HeaderMatcher extends Matcher {
  final Header header;

  _HeaderMatcher(this.header);

  @override
  Description describe(Description description) => description.add('Header');

  @override
  bool matches(item, Map matchState) {
    return item is Header &&
        _compareLists(item.name, header.name) &&
        _compareLists(item.value, header.value);
  }

  bool _compareLists(List<int> a, List<int> b) {
    if (a == null && b == null) return true;
    if (a == null && b != null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

Matcher isHeader(String name, String value) =>
    _HeaderMatcher(Header.ascii(name, value));

Matcher equalsHeader(Header header) => _HeaderMatcher(header);
