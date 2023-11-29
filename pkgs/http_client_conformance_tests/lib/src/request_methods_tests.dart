// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'request_methods_server_vm.dart'
    if (dart.library.html) 'request_methods_server_web.dart';

/// Tests that the [Client] correctly sends HTTP request methods
/// (e.g. GET, HEAD).
///
/// If [preservesMethodCase] is `false` then tests that assume that the
/// [Client] preserves custom request method casing will be skipped.
void testRequestMethods(Client client,
    {bool preservesMethodCase = true}) async {
  group('request methods', () {
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('custom method - not case preserving', () async {
      await client.send(Request(
        'CuStOm',
        Uri.http(host, ''),
      ));
      final method = await httpServerQueue.next as String;
      expect('CUSTOM', method.toUpperCase());
    });

    test('custom method case preserving', () async {
      await client.send(Request(
        'CuStOm',
        Uri.http(host, ''),
      ));
      final method = await httpServerQueue.next as String;
      expect('CuStOm', method);
    },
        skip: preservesMethodCase
            ? false
            : 'does not preserve HTTP request method case');

    test('delete', () async {
      await client.delete(Uri.http(host, ''));
      final method = await httpServerQueue.next as String;
      expect('DELETE', method);
    });

    test('get', () async {
      await client.get(Uri.http(host, ''));
      final method = await httpServerQueue.next as String;
      expect('GET', method);
    });
    test('head', () async {
      await client.head(Uri.http(host, ''));
      final method = await httpServerQueue.next as String;
      expect('HEAD', method);
    });

    test('patch', () async {
      await client.patch(Uri.http(host, ''));
      final method = await httpServerQueue.next as String;
      expect('PATCH', method);
    });

    test('post', () async {
      await client.post(Uri.http(host, ''));
      final method = await httpServerQueue.next as String;
      expect('POST', method);
    });

    test('put', () async {
      await client.put(Uri.http(host, ''));
      final method = await httpServerQueue.next as String;
      expect('PUT', method);
    });
  });
}
