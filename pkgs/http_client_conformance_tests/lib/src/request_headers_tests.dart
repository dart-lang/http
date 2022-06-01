// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';
import 'package:test/test.dart';

/// Tests that the [Client] correctly sends headers in the request.
void testRequestHeaders(Client client) async {
  group('client headers', () {
    test('single header', () async {
      late HttpHeaders requestHeaders;
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          requestHeaders = request.headers;
          unawaited(request.response.close());
        });
      await client.get(Uri.parse('http://localhost:${server.port}'),
          headers: {'foo': 'bar'});
      expect(requestHeaders['foo'], ['bar']);
      await server.close();
    });

    test('UPPER case header', () async {
      late HttpHeaders requestHeaders;
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          requestHeaders = request.headers;
          unawaited(request.response.close());
        });
      await client.get(Uri.parse('http://localhost:${server.port}'),
          headers: {'FOO': 'BAR'});
      // RFC 2616 14.44 states that header field names are case-insensive.
      // http.Client canonicalizes field names into lower case.
      expect(requestHeaders['foo'], ['BAR']);
      await server.close();
    });

    test('test headers different only in case', () async {
      // RFC 2616 14.44 states that header field names are case-insensive.
      late HttpHeaders requestHeaders;
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          requestHeaders = request.headers;
          unawaited(request.response.close());
        });
      await client.get(Uri.parse('http://localhost:${server.port}'),
          headers: {'foo': 'bar', 'Foo': 'Bar'});
      expect(requestHeaders['foo']!.first, isIn(['bar', 'Bar']));
      await server.close();
    });

    test('multiple headers', () async {
      late HttpHeaders requestHeaders;
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          requestHeaders = request.headers;
          unawaited(request.response.close());
        });
      // The `http.Client` API does not offer a way of sending the name field
      // more than once.
      await client.get(Uri.parse('http://localhost:${server.port}'),
          headers: {'list': 'apple, orange'});
      expect(requestHeaders['list'], ['apple, orange']);
      await server.close();
    });

    test('multiple values per header', () async {
      late HttpHeaders requestHeaders;
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          requestHeaders = request.headers;
          unawaited(request.response.close());
        });
      // The `http.Client` API does not offer a way of sending the same field
      // more than once.
      await client.get(Uri.parse('http://localhost:${server.port}'),
          headers: {'list': 'apple, orange'});

      expect(requestHeaders['list'], ['apple, orange']);
      await server.close();
    });
  });
}
