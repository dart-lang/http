// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:async/async.dart';
import 'package:test/test.dart';

import 'package:http/http.dart' as http;

import 'utils.dart';

void main() {
  group('#contentLength', () {
    test('is computed from bodyBytes', () {
      var request = new http.Request('POST', dummyUrl, body: [1, 2, 3, 4, 5]);
      expect(request.contentLength, equals(5));
      request = new http.Request('POST', dummyUrl,
          body: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(request.contentLength, equals(10));
    });

    test('is computed from body', () {
      var request = new http.Request('POST', dummyUrl, body: 'hello');
      expect(request.contentLength, equals(5));
      request = new http.Request('POST', dummyUrl, body: 'hello, world');
      expect(request.contentLength, equals(12));
    });
  });

  group('#encoding', () {
    test('defaults to utf-8', () {
      var request = new http.Request('POST', dummyUrl);
      expect(request.encoding.name, equals(UTF8.name));
    });

    test('can be set', () {
      var request = new http.Request('POST', dummyUrl, encoding: LATIN1);
      expect(request.encoding.name, equals(LATIN1.name));
    });

    test('is based on the content-type charset if it exists', () {
      var request = new http.Request('POST', dummyUrl,
          headers: {'Content-Type': 'text/plain; charset=iso-8859-1'});
      expect(request.encoding.name, equals(LATIN1.name));
    });

    test('throws an error if the content-type charset is unknown', () {
      var request = new http.Request('POST', dummyUrl,
          headers: {'Content-Type': 'text/plain; charset=not-a-real-charset'});
      expect(() => request.encoding, throwsFormatException);
    });
  });

  group('#bodyBytes', () {
    test('defaults to empty', () {
      var request = new http.Request('POST', dummyUrl);
      expect(collectBytes(request.read()), completion(isEmpty));
    });
  });

  group('#body', () {
    test('defaults to empty', () {
      var request = new http.Request('POST', dummyUrl);
      expect(request.readAsString(), completion(isEmpty));
    });

    test('is encoded according to the given encoding', () {
      var request =
          new http.Request('POST', dummyUrl, encoding: LATIN1, body: 'föøbãr');
      expect(collectBytes(request.read()),
          completion(equals([102, 246, 248, 98, 227, 114])));
    });

    test('is decoded according to the given encoding', () {
      var request = new http.Request('POST', dummyUrl,
          encoding: LATIN1, body: [102, 246, 248, 98, 227, 114]);
      expect(request.readAsString(), completion(equals('föøbãr')));
    });
  });

  group('#bodyFields', () {
    test('is encoded according to the given encoding', () {
      var request = new http.Request('POST', dummyUrl,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          encoding: LATIN1,
          body: {'föø': 'bãr'});
      expect(request.readAsString(), completion(equals('f%F6%F8=b%E3r')));
    });
  });

  group('content-type header', () {
    test('defaults to empty', () {
      var request = new http.Request('POST', dummyUrl);
      expect(request.headers['Content-Type'], isNull);
    });

    test('defaults to empty if only encoding is set', () {
      var request = new http.Request('POST', dummyUrl, encoding: LATIN1);
      expect(request.headers['Content-Type'], isNull);
    });

    test('name is case insensitive', () {
      var request = new http.Request('POST', dummyUrl,
          headers: {'CoNtEnT-tYpE': 'application/json'});
      expect(request.headers, containsPair('content-type', 'application/json'));
    });

    test(
        'is set to application/x-www-form-urlencoded with charset utf-8 if '
        'bodyFields is set', () {
      var request =
          new http.Request('POST', dummyUrl, body: {'hello': 'world'});
      expect(request.headers['Content-Type'],
          equals('application/x-www-form-urlencoded; charset=utf-8'));
    });

    test(
        'is set to application/x-www-form-urlencoded with the given charset '
        'if bodyFields and encoding are set', () {
      var request = new http.Request('POST', dummyUrl,
          encoding: LATIN1, body: {'hello': 'world'});
      expect(request.headers['Content-Type'],
          equals('application/x-www-form-urlencoded; charset=iso-8859-1'));
    });

    test(
        'is set to text/plain and the given encoding if body and encoding are '
        'both set', () {
      var request = new http.Request('POST', dummyUrl,
          encoding: LATIN1, body: 'hello, world');
      expect(request.headers['Content-Type'],
          equals('text/plain; charset=iso-8859-1'));
    });

    test('is modified to include utf-8 if body is set', () {
      var request = new http.Request('POST', dummyUrl,
          headers: {'Content-Type': 'application/json'},
          body: '{"hello": "world"}');
      expect(request.headers['Content-Type'],
          equals('application/json; charset=utf-8'));
    });

    test('is modified to include the given encoding if encoding is set', () {
      var request = new http.Request('POST', dummyUrl,
          headers: {'Content-Type': 'application/json'}, encoding: LATIN1);
      expect(request.headers['Content-Type'],
          equals('application/json; charset=iso-8859-1'));
    });

    test('has its charset overridden by an explicit encoding', () {
      var request = new http.Request('POST', dummyUrl,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          encoding: LATIN1);
      expect(request.headers['Content-Type'],
          equals('application/json; charset=iso-8859-1'));
    });

    test("doesn't have its charset overridden by setting bodyFields", () {
      var request = new http.Request('POST', dummyUrl, headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=iso-8859-1'
      }, body: {
        'hello': 'world'
      });
      expect(request.headers['Content-Type'],
          equals('application/x-www-form-urlencoded; charset=iso-8859-1'));
    });

    test("doesn't have its charset overridden by setting body", () {
      var request = new http.Request('POST', dummyUrl,
          headers: {'Content-Type': 'application/json; charset=iso-8859-1'},
          body: '{"hello": "world"}');
      expect(request.headers['Content-Type'],
          equals('application/json; charset=iso-8859-1'));
    });
  });

  group('change', () {
    test('with no arguments returns instance with equal values', () {
      var request = new http.Request('GET', dummyUrl,
          headers: {'header1': 'header value 1'},
          body: 'hello, world',
          context: {'context1': 'context value 1'});

      var copy = request.change();

      expect(copy.method, request.method);
      expect(copy.headers, same(request.headers));
      expect(copy.url, request.url);
      expect(copy.context, same(request.context));
      expect(copy.readAsString(), completion('hello, world'));
    });

    test('allows the original request to be read', () {
      var request = new http.Request('GET', dummyUrl);
      var changed = request.change();

      expect(request.read().toList(), completion(isEmpty));
      expect(changed.read, throwsStateError);
    });

    test('allows the changed request to be read', () {
      var request = new http.Request('GET', dummyUrl);
      var changed = request.change();

      expect(changed.read().toList(), completion(isEmpty));
      expect(request.read, throwsStateError);
    });

    test('allows another changed request to be read', () {
      var request = new http.Request('GET', dummyUrl);
      var changed1 = request.change();
      var changed2 = request.change();

      expect(changed2.read().toList(), completion(isEmpty));
      expect(changed1.read, throwsStateError);
      expect(request.read, throwsStateError);
    });
  });
}
