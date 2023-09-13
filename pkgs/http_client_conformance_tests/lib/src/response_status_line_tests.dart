// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'response_status_line_server_vm.dart'
    if (dart.library.html) 'response_status_line_server_web.dart';

/// Tests that the [Client] correctly processes the response status line.
void testResponseStatusLine(Client client) async {
  group('response status line', () {
    late String host;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });

    test(
      'without HTTP version',
      () async {
        httpServerChannel.sink.add('200 OK');
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
        await expectLater(
          client.get(Uri.http(host, '')),
          anyOf(
              throwsA(isA<ClientException>()),
              predicate<Response>(
                  (response) => response.reasonPhrase == 'Created'),
              'reason phrase is "Created"'),
        );
      },
    );
  });
}
