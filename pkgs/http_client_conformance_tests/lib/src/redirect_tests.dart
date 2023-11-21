// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'redirect_server_vm.dart'
    if (dart.library.js_interop) 'redirect_server_web.dart';

/// Tests that the [Client] correctly implements HTTP redirect logic.
///
/// If [redirectAlwaysAllowed] is `true` then tests that require the [Client]
/// to limit redirects will be skipped.
void testRedirect(Client client, {bool redirectAlwaysAllowed = false}) async {
  group('redirects', () {
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('disallow redirect', () async {
      final request = Request('GET', Uri.http(host, '/1'))
        ..followRedirects = false;
      final response = await client.send(request);
      expect(response.statusCode, 302);
      expect(response.isRedirect, true);
    }, skip: redirectAlwaysAllowed ? 'redirects always allowed' : false);

    test('disallow redirect, 0 maxRedirects', () async {
      final request = Request('GET', Uri.http(host, '/1'))
        ..followRedirects = false
        ..maxRedirects = 0;
      final response = await client.send(request);
      expect(response.statusCode, 302);
      expect(response.isRedirect, true);
    }, skip: redirectAlwaysAllowed ? 'redirects always allowed' : false);

    test('allow redirect', () async {
      final request = Request('GET', Uri.http(host, '/1'))
        ..followRedirects = true;
      final response = await client.send(request);
      expect(response.statusCode, 200);
      expect(response.isRedirect, false);
    });

    test('allow redirect, 0 maxRedirects', () async {
      final request = Request('GET', Uri.http(host, '/1'))
        ..followRedirects = true
        ..maxRedirects = 0;
      expect(
          client.send(request),
          throwsA(isA<ClientException>()
              .having((e) => e.message, 'message', 'Redirect limit exceeded')));
    }, skip: redirectAlwaysAllowed ? 'redirects always allowed' : false);

    test('exactly the right number of allowed redirects', () async {
      final request = Request('GET', Uri.http(host, '/5'))
        ..followRedirects = true
        ..maxRedirects = 5;
      final response = await client.send(request);
      expect(response.statusCode, 200);
      expect(response.isRedirect, false);
    }, skip: redirectAlwaysAllowed ? 'redirects always allowed' : false);

    test('too many redirects', () async {
      final request = Request('GET', Uri.http(host, '/6'))
        ..followRedirects = true
        ..maxRedirects = 5;
      expect(
          client.send(request),
          throwsA(isA<ClientException>()
              .having((e) => e.message, 'message', 'Redirect limit exceeded')));
    }, skip: redirectAlwaysAllowed ? 'redirects always allowed' : false);

    test(
      'loop',
      () async {
        final request = Request('GET', Uri.http(host, '/loop'))
          ..followRedirects = true
          ..maxRedirects = 5;
        expect(client.send(request), throwsA(isA<ClientException>()));
      },
    );
  });
}
