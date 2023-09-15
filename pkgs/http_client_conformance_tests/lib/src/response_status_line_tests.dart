// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'response_status_line_server_vm.dart'
    if (dart.library.html) 'response_status_line_server_web.dart';

/// Tests that the [Client] correctly processes the response status line (e.g.
/// 'HTTP/1.1 200 OK\r\n').
///
/// If [reasonableInvalidStatusLineHandling] is `false` the tests related to
/// invalid `Status-Line`s are skipped.
void testResponseStatusLine(Client client,
    {bool reasonableInvalidStatusLineHandling = true}) async {
  group('response status line', () {
    late String host;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });

    test('valid', () async {
      httpServerChannel.sink.add('HTTP/1.1 201 Created');
      final response = await client.get(Uri.http(host, '');
      expect(response.statusCode, 201);
      expect(response.reasonPhrase, 'Created');
    });

    group('invalid', () {
      test(
        'without HTTP version',
        () async {
          httpServerChannel.sink.add('201 Created');
          await expectLater(
            client.get(Uri.http(host, '')),
            throwsA(isA<ClientException>()),
          );
        },
      );

      test(
        'without status code',
        () async {
          httpServerChannel.sink.add('HTTP/1.1 OK');
          await expectLater(
            client.get(Uri.http(host, '')),
            throwsA(isA<ClientException>()),
          );
        },
      );

      test(
        'without reason phrase',
        () async {
          httpServerChannel.sink.add('HTTP/1.1 201');
          try {
            final response = await client.get(Uri.http(host, ''));
            expect(response.statusCode, 201);
            // All of these responses seem reasonable.
            expect(response.reasonPhrase, anyOf(isNull, '', 'Created'));
          } on ClientException {
            // A Reason-Phrase is required according to RFC-2616
          }
        },
      );
    },
        skip: reasonableInvalidStatusLineHandling
            ? false
            : 'does handle invalid request lines in a sensible way');
  });
}
