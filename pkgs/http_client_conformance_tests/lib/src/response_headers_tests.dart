// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';
import 'package:test/test.dart';

/// Tests that the [Client] correctly processes response headers e.g.
/// 'Content-Length'.
void testResponseHeaders(Client client) async {
  group('server headers', () {
    test('single header', () async {
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          var response = request.response;
          response.headers.set('foo', 'bar');
          unawaited(response.close());
        });
      final response =
          await client.get(Uri.parse('http://localhost:${server.port}'));
      expect(response.headers['foo'], 'bar');
      await server.close();
    });

    test('UPPERCASE header', () async {
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          var response = request.response;
          response.headers.set('FOO', 'BAR', preserveHeaderCase: true);
          unawaited(response.close());
        });
      // RFC 2616 14.44 states that header field names are case-insensive.
      // http.Client canonicalizes field names into lower case.
      final response =
          await client.get(Uri.parse('http://localhost:${server.port}'));
      expect(response.headers['foo'], 'BAR');
      await server.close();
    });

    test('multiple headers', () async {
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          var response = request.response;
          response.headers
            ..set('field1', 'value1')
            ..set('field2', 'value2')
            ..set('field3', 'value3');
          unawaited(response.close());
        });
      final response =
          await client.get(Uri.parse('http://localhost:${server.port}'));
      expect(response.headers['field1'], 'value1');
      expect(response.headers['field2'], 'value2');
      expect(response.headers['field3'], 'value3');
      await server.close();
    });

    test('multiple values per header', () async {
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          var response = request.response;
          // RFC 2616 14.44 states that header field names are case-insensive.
          response.headers
            ..add('list', 'apple')
            ..add('list', 'orange')
            ..add('List', 'banana');
          unawaited(response.close());
        });
      final response =
          await client.get(Uri.parse('http://localhost:${server.port}'));
      expect(response.headers['list'], 'apple, orange, banana');
      await server.close();
    });
  });
}
