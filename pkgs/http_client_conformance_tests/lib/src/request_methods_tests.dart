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
void testRequestMethods(Client client) async {
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

    test('custom method', () async {
      await client.send(Request(
        'CUSTOM',
        Uri.http(host, ''),
      ));
      final method = await httpServerQueue.next as String;
      expect('CUSTOM', method);
    });

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
