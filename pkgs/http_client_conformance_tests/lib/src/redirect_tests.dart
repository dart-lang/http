// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';
import 'package:test/test.dart';

/// Tests that the [Client] correctly implements HTTP redirect logic.
void testRedirect(Client client) async {
  group('redirects', () {
    late HttpServer server;
    setUp(() async {
      //        URI |  Redirects TO
      // ===========|==============
      // ".../loop" |    ".../loop"
      //   ".../10" |       ".../9"
      //    ".../9" |       ".../8"
      //        ... |           ...
      //    ".../1" |           "/"
      //        "/" |  <no redirect>
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          if (request.requestedUri.pathSegments.isEmpty) {
            unawaited(request.response.close());
          } else if (request.requestedUri.pathSegments.last == 'loop') {
            unawaited(request.response
                .redirect(Uri.parse('http://localhost:${server.port}/loop')));
          } else {
            final n = int.parse(request.requestedUri.pathSegments.last);
            final nextPath = n - 1 == 0 ? '' : '${n - 1}';
            unawaited(request.response.redirect(
                Uri.parse('http://localhost:${server.port}/$nextPath')));
          }
        });
    });
    tearDown(() => server.close);

    test('disallow redirect', () async {
      final request =
          Request('GET', Uri.parse('http://localhost:${server.port}/1'))
            ..followRedirects = false;
      final response = await client.send(request);
      expect(response.statusCode, 302);
      expect(response.isRedirect, true);
    });

    test('allow redirect', () async {
      final request =
          Request('GET', Uri.parse('http://localhost:${server.port}/1'))
            ..followRedirects = true;
      final response = await client.send(request);
      expect(response.statusCode, 200);
      expect(response.isRedirect, false);
    });

    test('allow redirect, 0 maxRedirects, ', () async {
      final request =
          Request('GET', Uri.parse('http://localhost:${server.port}/1'))
            ..followRedirects = true
            ..maxRedirects = 0;
      expect(
          client.send(request),
          throwsA(isA<ClientException>()
              .having((e) => e.message, 'message', 'Redirect limit exceeded')));
    },
        skip: 'Re-enable after https://github.com/dart-lang/sdk/issues/49012 '
            'is fixed');

    test('exactly the right number of allowed redirects', () async {
      final request =
          Request('GET', Uri.parse('http://localhost:${server.port}/5'))
            ..followRedirects = true
            ..maxRedirects = 5;
      final response = await client.send(request);
      expect(response.statusCode, 200);
      expect(response.isRedirect, false);
    });

    test('too many redirects', () async {
      final request =
          Request('GET', Uri.parse('http://localhost:${server.port}/6'))
            ..followRedirects = true
            ..maxRedirects = 5;
      expect(
          client.send(request),
          throwsA(isA<ClientException>()
              .having((e) => e.message, 'message', 'Redirect limit exceeded')));
    });

    test('loop', () async {
      final request =
          Request('GET', Uri.parse('http://localhost:${server.port}/loop'))
            ..followRedirects = true
            ..maxRedirects = 5;
      expect(
          client.send(request),
          throwsA(isA<ClientException>().having((e) => e.message, 'message',
              isIn(['Redirect loop detected', 'Redirect limit exceeded']))));
    });
  });
}
