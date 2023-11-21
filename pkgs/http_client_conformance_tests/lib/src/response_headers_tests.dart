// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'response_headers_server_vm.dart'
    if (dart.library.js_interop) 'response_headers_server_web.dart';

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
      httpServerChannel.sink.add('foo: bar\r\n');

      final response = await client.get(Uri.http(host, ''));
      expect(response.headers['foo'], 'bar');
    });

    test('UPPERCASE header name', () async {
      // RFC 2616 14.44 states that header field names are case-insensitive.
      // http.Client canonicalizes field names into lower case.
      httpServerChannel.sink.add('FOO: bar\r\n');

      final response = await client.get(Uri.http(host, ''));
      expect(response.headers['foo'], 'bar');
    });

    test('UPPERCASE header value', () async {
      httpServerChannel.sink.add('foo: BAR\r\n');

      final response = await client.get(Uri.http(host, ''));
      expect(response.headers['foo'], 'BAR');
    });

    test('space surrounding header value', () async {
      httpServerChannel.sink.add('foo: \t BAR \t \r\n');

      final response = await client.get(Uri.http(host, ''));
      expect(response.headers['foo'], 'BAR');
    });

    test('space in header value', () async {
      httpServerChannel.sink.add('foo: BAR BAZ\r\n');

      final response = await client.get(Uri.http(host, ''));
      expect(response.headers['foo'], 'BAR BAZ');
    });

    test('multiple spaces in header value', () async {
      // RFC 2616 4.2 allows LWS between header values to be replace with a
      // single space.
      // See https://datatracker.ietf.org/doc/html/rfc2616#section-4.2
      httpServerChannel.sink.add('foo: BAR  \t   BAZ\r\n');

      final response = await client.get(Uri.http(host, ''));
      expect(
          response.headers['foo'], matches(RegExp('BAR {0,2}[ \t] {0,3}BAZ')));
    });

    test('multiple headers', () async {
      httpServerChannel.sink
          .add('field1: value1\r\n' 'field2: value2\r\n' 'field3: value3\r\n');

      final response = await client.get(Uri.http(host, ''));
      expect(response.headers['field1'], 'value1');
      expect(response.headers['field2'], 'value2');
      expect(response.headers['field3'], 'value3');
    });

    test('multiple values per header', () async {
      // RFC-2616 4.2 says:
      // "The field value MAY be preceded by any amount of LWS, though a single
      // SP is preferred." and
      // "The field-content does not include any leading or trailing LWS ..."
      httpServerChannel.sink.add('list: apple, orange, banana\r\n');

      final response = await client.get(Uri.http(host, ''));
      expect(response.headers['list'],
          matches(r'apple[ \t]*,[ \t]*orange[ \t]*,[ \t]*banana'));
    });

    test('multiple values per header surrounded with spaces', () async {
      httpServerChannel.sink
          .add('list: \t apple \t, \t orange \t , \t banana\t \t \r\n');

      final response = await client.get(Uri.http(host, ''));
      expect(response.headers['list'],
          matches(r'apple[ \t]*,[ \t]*orange[ \t]*,[ \t]*banana'));
    });

    test('multiple headers with the same name', () async {
      httpServerChannel.sink.add('list: apple\r\n'
          'list: orange\r\n'
          'list: banana\r\n');

      final response = await client.get(Uri.http(host, ''));
      expect(response.headers['list'],
          matches(r'apple[ \t]*,[ \t]*orange[ \t]*,[ \t]*banana'));
    });

    test('multiple headers with the same name but different cases', () async {
      httpServerChannel.sink.add('list: apple\r\n'
          'LIST: orange\r\n'
          'List: banana\r\n');

      final response = await client.get(Uri.http(host, ''));
      expect(response.headers['list'],
          matches(r'apple[ \t]*,[ \t]*orange[ \t]*,[ \t]*banana'));
    });

    group('content length', () {
      test('surrounded in spaces', () async {
        // RFC-2616 4.2 says:
        // "The field value MAY be preceded by any amount of LWS, though a
        // single SP is preferred." and
        // "The field-content does not include any leading or trailing LWS ..."
        httpServerChannel.sink.add('content-length: \t 0 \t \r\n');
        final response = await client.get(Uri.http(host, ''));
        expect(response.contentLength, 0);
      },
          skip: 'Enable after https://github.com/dart-lang/sdk/issues/51532 '
              'is fixed');

      test('non-integer', () async {
        httpServerChannel.sink.add('content-length: cat\r\n');
        await expectLater(
            client.get(Uri.http(host, '')), throwsA(isA<ClientException>()));
      });

      test('negative', () async {
        httpServerChannel.sink.add('content-length: -5\r\n');
        await expectLater(
            client.get(Uri.http(host, '')), throwsA(isA<ClientException>()));
      });

      test('bigger than actual body', () async {
        httpServerChannel.sink.add('content-length: 100\r\n');
        await expectLater(
            client.get(Uri.http(host, '')), throwsA(isA<ClientException>()));
      });
    });

    group('folded headers', () {
      // RFC2616 says that HTTP Headers can be split across multiple lines.
      // See https://datatracker.ietf.org/doc/html/rfc2616#section-2.2
      test('leading space', () async {
        httpServerChannel.sink.add('foo: BAR\r\n BAZ\r\n');

        final response = await client.get(Uri.http(host, ''));
        expect(response.headers['foo'], 'BAR BAZ');
      },
          skip: 'Enable after https://github.com/dart-lang/sdk/issues/53185 '
              'is fixed');

      test('extra whitespace', () async {
        httpServerChannel.sink.add('foo: BAR   \t   \r\n   \t   BAZ \t \r\n');

        final response = await client.get(Uri.http(host, ''));
        // RFC 2616 4.2 allows LWS between header values to be replace with a
        // single space.
        expect(
            response.headers['foo'],
            allOf(matches(RegExp(r'BAR {0,3}[ \t]? {0,7}[ \t]? {0,3}BAZ')),
                contains(' ')));
      });
    });
  });
}
