// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// Tests that the [Client] correctly processes response headers.
///
/// If [packageRoot] is set then it will be used as the filesystem root
/// directory of `package:http_client_conformance_tests`. If it is not set then
/// `Isolate.resolvePackageUri` will be used to discover the package root.
/// NOTE: Setting this parameter is only needed in the browser environment,
/// where `Isolate.resolvePackageUri` doesn't work.
void testResponseHeaders(Client client, {String? packageRoot}) async {
  group('server headers', () {
    late String host;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel =
          await startServer('response_headers_server.dart', packageRoot);
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
      // RFC 2616 14.44 states that header field names are case-insensive.
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
