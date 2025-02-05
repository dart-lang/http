// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('()', () {
    test('sets body', () {
      var response = http.Response('Hello, world!', 200);
      expect(response.body, equals('Hello, world!'));
    });

    test('sets bodyBytes', () {
      var response = http.Response('Hello, world!', 200);
      expect(
          response.bodyBytes,
          equals(
              [72, 101, 108, 108, 111, 44, 32, 119, 111, 114, 108, 100, 33]));
    });

    test('respects the inferred encoding', () {
      var response = http.Response('föøbãr', 200,
          headers: {'content-type': 'text/plain; charset=iso-8859-1'});
      expect(response.bodyBytes, equals([102, 246, 248, 98, 227, 114]));
    });
  });

  group('.bytes()', () {
    test('sets body', () {
      var response = http.Response.bytes([104, 101, 108, 108, 111], 200);
      expect(response.body, equals('hello'));
    });

    test('sets bodyBytes', () {
      var response = http.Response.bytes([104, 101, 108, 108, 111], 200);
      expect(response.bodyBytes, equals([104, 101, 108, 108, 111]));
    });

    test('respects the inferred encoding', () {
      var response = http.Response.bytes([102, 246, 248, 98, 227, 114], 200,
          headers: {'content-type': 'text/plain; charset=iso-8859-1'});
      expect(response.body, equals('föøbãr'));
    });

    test(
        'decoding with empty charset if content type is application/json, Russian text',
        () {
      final utf8Bytes = utf8.encode('{"foo":"Привет, мир!"}');
      var response = http.Response.bytes(utf8Bytes, 200,
          headers: {'content-type': 'application/json'});
      expect(response.body, equals('{"foo":"Привет, мир!"}'));
    });

    test(
        'test decoding with empty charset if content type is application/json, Chinese text',
        () {
      final chineseUtf8Bytes = utf8.encode('{"foo":"你好，世界！"}');
      var responseChinese = http.Response.bytes(chineseUtf8Bytes, 200,
          headers: {'content-type': 'application/json'});

      expect(responseChinese.body, equals('{"foo":"你好，世界！"}'));
    });

    test(
        'test decoding with empty charset if content type is application/json, Korean text',
        () {
      final koreanUtf8Bytes = utf8.encode('{"foo":"안녕하세요, 세계!"}');
      var responseKorean = http.Response.bytes(koreanUtf8Bytes, 200,
          headers: {'content-type': 'application/json'});
      expect(responseKorean.body, equals('{"foo":"안녕하세요, 세계!"}'));
    });

    test('respects the inferred encoding for application/json content-type',
        () {
      final latin1Bytes = latin1.encode('{"foo":"Olá, mundo!"}');
      var response = http.Response.bytes(latin1Bytes, 200,
          headers: {'content-type': 'application/json; charset=iso-8859-1'});
      expect(response.body, equals('{"foo":"Olá, mundo!"}'));
    });

    test('latin1 decode on empty charset if content type is text/plain', () {
      final latin1Bytes = latin1.encode('Hello, wold!');
      var response = http.Response.bytes(latin1Bytes, 200,
          headers: {'content-type': 'text/plain'});
      expect(response.body, equals('Hello, wold!'));
    });
  });

  group('.fromStream()', () {
    test('sets body', () async {
      var controller = StreamController<List<int>>(sync: true);
      var streamResponse =
          http.StreamedResponse(controller.stream, 200, contentLength: 13);
      controller
        ..add([72, 101, 108, 108, 111, 44, 32])
        ..add([119, 111, 114, 108, 100, 33]);
      unawaited(controller.close());
      var response = await http.Response.fromStream(streamResponse);
      expect(response.body, equals('Hello, world!'));
    });

    test('sets bodyBytes', () async {
      var controller = StreamController<List<int>>(sync: true);
      var streamResponse =
          http.StreamedResponse(controller.stream, 200, contentLength: 5);
      controller.add([104, 101, 108, 108, 111]);
      unawaited(controller.close());
      var response = await http.Response.fromStream(streamResponse);
      expect(response.bodyBytes, equals([104, 101, 108, 108, 111]));
    });
  });

  group('.headersSplitValues', () {
    test('no headers', () async {
      var response = http.Response('Hello, world!', 200);
      expect(response.headersSplitValues, const <String, List<String>>{});
    });

    test('one header', () async {
      var response =
          http.Response('Hello, world!', 200, headers: {'fruit': 'apple'});
      expect(response.headersSplitValues, const {
        'fruit': ['apple']
      });
    });

    test('two headers', () async {
      var response = http.Response('Hello, world!', 200,
          headers: {'fruit': 'apple,banana'});
      expect(response.headersSplitValues, const {
        'fruit': ['apple', 'banana']
      });
    });

    test('two headers with lots of spaces', () async {
      var response = http.Response('Hello, world!', 200,
          headers: {'fruit': 'apple   \t   ,  \tbanana'});
      expect(response.headersSplitValues, const {
        'fruit': ['apple', 'banana']
      });
    });

    test('one set-cookie', () async {
      var response = http.Response('Hello, world!', 200, headers: {
        'set-cookie': 'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT'
      });
      expect(response.headersSplitValues, const {
        'set-cookie': ['id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT']
      });
    });

    test('two set-cookie, with comma in expires', () async {
      var response = http.Response('Hello, world!', 200, headers: {
        // ignore: missing_whitespace_between_adjacent_strings
        'set-cookie': 'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT,'
            'sessionId=e8bb43229de9; Domain=foo.example.com'
      });
      expect(response.headersSplitValues, const {
        'set-cookie': [
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT',
          'sessionId=e8bb43229de9; Domain=foo.example.com'
        ]
      });
    });

    test('two set-cookie, with lots of commas', () async {
      var response = http.Response('Hello, world!', 200, headers: {
        'set-cookie':
            // ignore: missing_whitespace_between_adjacent_strings
            'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO,'
                'sessionId=e8bb43229de9; Domain=foo.example.com'
      });
      expect(response.headersSplitValues, const {
        'set-cookie': [
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO',
          'sessionId=e8bb43229de9; Domain=foo.example.com'
        ]
      });
    });
  });
}
