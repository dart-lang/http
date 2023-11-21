// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'request_headers_server_vm.dart'
    if (dart.library.js_interop) 'request_headers_server_web.dart';

/// Tests that the [Client] correctly sends headers in the request.
void testRequestHeaders(Client client) async {
  group('client headers', () {
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('single header', () async {
      await client.get(Uri.http(host, ''), headers: {'foo': 'bar'});

      final headers = await httpServerQueue.next as Map;
      expect(headers['foo'], ['bar']);
    });

    test('UPPER case header', () async {
      await client.get(Uri.http(host, ''), headers: {'FOO': 'BAR'});

      final headers = await httpServerQueue.next as Map;
      // RFC 2616 14.44 states that header field names are case-insensitive.
      // http.Client canonicalizes field names into lower case.
      expect(headers['foo'], ['BAR']);
    });

    test('test headers different only in case', () async {
      await client
          .get(Uri.http(host, ''), headers: {'foo': 'bar', 'Foo': 'Bar'});

      final headers = await httpServerQueue.next as Map;
      // ignore: avoid_dynamic_calls
      expect(headers['foo']!.single, isIn(['bar', 'Bar']));
    });

    test('multiple headers', () async {
      // The `http.Client` API does not offer a way of sending the name field
      // more than once.
      await client
          .get(Uri.http(host, ''), headers: {'fruit': 'apple', 'color': 'red'});

      final headers = await httpServerQueue.next as Map;
      expect(headers['fruit'], ['apple']);
      expect(headers['color'], ['red']);
    });

    test('multiple values per header', () async {
      // The `http.Client` API does not offer a way of sending the same field
      // more than once.
      await client.get(Uri.http(host, ''), headers: {'list': 'apple, orange'});

      final headers = await httpServerQueue.next as Map;
      expect(headers['list'], ['apple, orange']);
    });
  });
}
