// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:charcode/charcode.dart';
import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';

void main() {
  group("encode", () {
    test("base64-encodes data by default", () {
      var uri = new DataUri.encode([1, 2, 3, 4]);
      expect(uri.toString(), equals("data:;base64,AQIDBA=="));
    });

    test("doesn't use URL-safe base64 encoding", () {
      var uri = new DataUri.encode([0xFB, 0xFF]);
      expect(uri.toString(), equals("data:;base64,+/8="));
    });

    test("percent-encodes data if base64 is disabled", () {
      var uri = new DataUri.encode([$a, $B, $plus, $slash, 0xFF],
          base64: false);
      expect(uri.toString(), equals("data:,aB%2B%2F%FF"));
    });

    test("includes a media type and its parameters", () {
      var mediaType = new MediaType('text', 'html', {
        'foo': 'bar',
        'baz': 'bang'
      });
      var uri = new DataUri.encode([], mediaType: mediaType);
      expect(uri.toString(), equals('data:text/html;foo=bar;baz=bang;base64,'));
    });

    test("percent-encodes the media type and its parameters", () {
      var mediaType = new MediaType('te=xt', 'ht%ml', {'f;oo': 'ba,r'});
      var uri = new DataUri.encode([], mediaType: mediaType);
      expect(uri.toString(),
          equals('data:te%3Dxt/ht%25ml;f%3Boo=ba%2Cr;base64,'));
    });

    test("UTF-8 encodes non-ASCII characters", () {
      var mediaType = new MediaType('tëxt', 'ћtml', {'føo': 'bår'});
      var uri = new DataUri.encode([], mediaType: mediaType);
      expect(uri.toString(),
          equals('data:t%C3%ABxt/%D1%9Btml;f%C3%B8o=b%C3%A5r;base64,'));
    });

    test("doesn't include a text/plain media type", () {
      var mediaType = new MediaType('text', 'plain', {'foo': 'bar'});
      var uri = new DataUri.encode([], mediaType: mediaType);
      expect(uri.toString(), equals('data:;foo=bar;base64,'));
    });

    group("with a string", () {
      test("defaults to ASCII if it's sufficient", () {
        var uri = new DataUri.encodeString('foo');
        expect(uri.toString(), equals("data:;base64,Zm9v"));
      });

      test("defaults to UTF-8 encoding if it's needed", () {
        var uri = new DataUri.encodeString('føo');
        expect(uri.toString(), equals("data:;charset=utf-8;base64,ZsO4bw=="));
      });

      test("obeys a passed encoding", () {
        var uri = new DataUri.encodeString('føo', encoding: LATIN1);
        expect(uri.toString(), equals("data:;charset=iso-8859-1;base64,Zvhv"));
      });

      test("obeys a media type encoding", () {
        var mediaType = new MediaType('text', 'plain',
            {'charset': 'iso-8859-1'});
        var uri = new DataUri.encodeString('føo', mediaType: mediaType);
        expect(uri.toString(), equals("data:;charset=iso-8859-1;base64,Zvhv"));
      });

      test("obeys a passed encoding that matches a media type encoding", () {
        var mediaType = new MediaType('text', 'plain',
            {'charset': 'iso-8859-1'});
        var uri = new DataUri.encodeString('føo',
            encoding: LATIN1, mediaType: mediaType);
        expect(uri.toString(), equals("data:;charset=iso-8859-1;base64,Zvhv"));
      });

      test("throws if a media type encoding is unsupported", () {
        var mediaType = new MediaType('text', 'plain', {'charset': 'fblthp'});
        expect(() => new DataUri.encodeString('føo', mediaType: mediaType),
            throwsUnsupportedError);
      });

      test("throws if a passed encoding disagrees with a media type encoding",
          () {
        var mediaType = new MediaType('text', 'plain', {'charset': 'utf-8'});
        expect(() {
          new DataUri.encodeString('føo',
              encoding: LATIN1, mediaType: mediaType);
        }, throwsArgumentError);
      });
    });
  });

  group("decode", () {
    test("decodes a base64 URI", () {
      var uri = new DataUri.decode("data:;base64,AQIDBA==");
      expect(uri.data, equals([1, 2, 3, 4]));
    });

    test("decodes a percent-encoded URI", () {
      var uri = new DataUri.decode("data:,aB%2B%2F%FF");
      expect(uri.data, equals([$a, $B, $plus, $slash, 0xFF]));
    });

    test("decodes a media type and its parameters", () {
      var uri = new DataUri.decode("data:text/html;foo=bar;baz=bang;base64,");
      expect(uri.data, isEmpty);
      expect(uri.mediaType.type, equals('text'));
      expect(uri.mediaType.subtype, equals('html'));
      expect(uri.mediaType.parameters, equals({
        'foo': 'bar',
        'baz': 'bang'
      }));
    });

    test("defaults to a text/plain media type", () {
      var uri = new DataUri.decode("data:;base64,");
      expect(uri.mediaType.type, equals('text'));
      expect(uri.mediaType.subtype, equals('plain'));
      expect(uri.mediaType.parameters, equals({'charset': 'US-ASCII'}));
    });

    test("defaults to a text/plain media type with parameters", () {
      var uri = new DataUri.decode("data:;foo=bar;base64,");
      expect(uri.mediaType.type, equals('text'));
      expect(uri.mediaType.subtype, equals('plain'));
      expect(uri.mediaType.parameters, equals({'foo': 'bar'}));
    });

    test("percent-decodes the media type and its parameters", () {
      var uri = new DataUri.decode(
          'data:te%78t/ht%6Dl;f%6Fo=ba%2Cr;base64,');
      expect(uri.mediaType.type, equals('text'));
      expect(uri.mediaType.subtype, equals('html'));
      expect(uri.mediaType.parameters, equals({'foo': 'ba,r'}));
    });

    test("assumes the URI is UTF-8", () {
      var uri = new DataUri.decode(
          'data:t%C3%ABxt/%D1%9Btml;f%C3%B8o=b%C3%A5r;base64,');
      expect(uri.mediaType.type, equals('tëxt'));
      expect(uri.mediaType.subtype, equals('ћtml'));
      expect(uri.mediaType.parameters, equals({'føo': 'bår'}));
    });

    test("allows a parameter named base64", () {
      var uri = new DataUri.decode("data:;base64=no,foo");
      expect(uri.mediaType.parameters, equals({'base64': 'no'}));
      expect(uri.data, equals([$f, $o, $o]));
    });

    test("includes the query", () {
      var uri = new DataUri.decode("data:,a?b=c");
      expect(uri.data, equals([$a, $question, $b, $equal, $c]));
    });

    test("doesn't include the fragment", () {
      var uri = new DataUri.decode("data:,a#b=c");
      expect(uri.data, equals([$a]));
    });

    test("supports the URL-safe base64 alphabet", () {
      var uri = new DataUri.decode("data:;base64,-_8%3D");
      expect(uri.data, equals([0xFB, 0xFF]));
    });

    group("forbids", () {
      test("a parameter with the wrong type", () {
        expect(() => new DataUri.decode(12), throwsArgumentError);
      });

      test("a parameter with the wrong scheme", () {
        expect(() => new DataUri.decode("http:;base64,"), throwsArgumentError);
      });

      test("non-token characters in invalid positions", () {
        expect(() => new DataUri.decode("data:text//plain;base64,"),
            throwsFormatException);
        expect(() => new DataUri.decode("data:text/plain;;base64,"),
            throwsFormatException);
        expect(() => new DataUri.decode("data:text/plain;/base64,"),
            throwsFormatException);
        expect(() => new DataUri.decode("data:text/plain;,"),
            throwsFormatException);
        expect(() => new DataUri.decode("data:text/plain;base64;"),
            throwsFormatException);
        expect(() => new DataUri.decode("data:text/plain;foo=bar=baz;base64,"),
            throwsFormatException);
      });

      test("encoded non-token characters in invalid positions", () {
        expect(() => new DataUri.decode("data:te%2Cxt/plain;base64,"),
            throwsFormatException);
        expect(() => new DataUri.decode("data:text/pl%2Cain;base64,"),
            throwsFormatException);
        expect(() => new DataUri.decode("data:text/plain;f%2Coo=bar;base64,"),
            throwsFormatException);
      });
    });
  });

  group("dataAsString", () {
    test("decodes the data as ASCII by default", () {
      var uri = new DataUri.decode("data:;base64,Zm9v");
      expect(uri.dataAsString(), equals("foo"));

      uri = new DataUri.decode("data:;base64,ZsO4bw==");
      expect(() => uri.dataAsString(), throwsFormatException);
    });

    test("decodes the data using the declared charset", () {
      var uri = new DataUri.decode("data:;charset=iso-8859-1;base64,ZsO4bw==");
      expect(uri.dataAsString(), equals("fÃ¸o"));
    });

    test("throws if the charset isn't supported", () {
      var uri = new DataUri.decode("data:;charset=fblthp;base64,ZsO4bw==");
      expect(() => uri.dataAsString(), throwsUnsupportedError);
    });

    test("uses the given encoding in preference to the declared charset", () {
      var uri = new DataUri.decode("data:;charset=fblthp;base64,ZsO4bw==");
      expect(uri.dataAsString(encoding: UTF8), equals("føo"));

      uri = new DataUri.decode("data:;charset=utf-8;base64,ZsO4bw==");
      expect(uri.dataAsString(encoding: LATIN1), equals("fÃ¸o"));
    });
  });
}
