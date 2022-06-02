// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// Tests that the [Client] correctly implements HTTP redirect logic.
void testRedirect(Client client) async {
  group('redirects', () {
    late String host;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel = spawnHybridUri('../lib/src/redirect_server.dart');
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });
    tearDown(() => httpServerChannel.sink.add(null));

    test('disallow redirect', () async {
      final request = Request('GET', Uri.http(host, '/1'))
        ..followRedirects = false;
      final response = await client.send(request);
      expect(response.statusCode, 302);
      expect(response.isRedirect, true);
    }, onPlatform: {'browser': const Skip('not passing')});

    test('allow redirect', () async {
      final request = Request('GET', Uri.http(host, '/1'))
        ..followRedirects = true;
      final response = await client.send(request);
      expect(response.statusCode, 200);
      expect(response.isRedirect, false);
    });

    test('allow redirect, 0 maxRedirects, ', () async {
      final request = Request('GET', Uri.http(host, '/1'))
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
      final request = Request('GET', Uri.http(host, '/5'))
        ..followRedirects = true
        ..maxRedirects = 5;
      final response = await client.send(request);
      expect(response.statusCode, 200);
      expect(response.isRedirect, false);
    });

    test('too many redirects', () async {
      final request = Request('GET', Uri.http(host, '/6'))
        ..followRedirects = true
        ..maxRedirects = 5;
      expect(
          client.send(request),
          throwsA(isA<ClientException>()
              .having((e) => e.message, 'message', 'Redirect limit exceeded')));
    }, onPlatform: {'browser': const Skip('not passing')});

    test('loop', () async {
      final request = Request('GET', Uri.http(host, '/loop'))
        ..followRedirects = true
        ..maxRedirects = 5;
      expect(
          client.send(request),
          throwsA(isA<ClientException>().having((e) => e.message, 'message',
              isIn(['Redirect loop detected', 'Redirect limit exceeded']))));
    }, onPlatform: {'browser': const Skip('not passing')});
  });
}
