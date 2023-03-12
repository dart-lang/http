// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'response_headers_server_vm.dart'
    if (dart.library.html) 'response_headers_server_web.dart';

/// Tests that the [Client] correctly processes response headers.
void testResponseHeaders(Client client) async {
  group('server headers', () {
    late String host;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });

    test('single header', () async {
      httpServerChannel.sink.add({'foo': 'bar'});

      final response = await client.get(Uri.http(host, ''));
      expect(response.headers['foo'], 'bar');
    });

    test('UPPERCASE header', () async {
      httpServerChannel.sink.add({'foo': 'BAR'});

      final response = await client.get(Uri.http(host, ''));
      // RFC 2616 14.44 states that header field names are case-insensitive.
      // http.Client canonicalizes field names into lower case.
      expect(response.headers['foo'], 'BAR');
    });

    test('multiple headers', () async {
      httpServerChannel.sink
          .add({'field1': 'value1', 'field2': 'value2', 'field3': 'value3'});

      final response = await client.get(Uri.http(host, ''));
      expect(response.headers['field1'], 'value1');
      expect(response.headers['field2'], 'value2');
      expect(response.headers['field3'], 'value3');
    });

    test('multiple values per header', () async {
      httpServerChannel.sink.add({'list': 'apple, orange, banana'});

      final response = await client.get(Uri.http(host, ''));
      expect(response.headers['list'], 'apple, orange, banana');
    });
  });
}
