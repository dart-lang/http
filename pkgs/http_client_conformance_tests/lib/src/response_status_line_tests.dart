// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'response_status_line_server_vm.dart'
    if (dart.library.js_interop) 'response_status_line_server_web.dart';

/// Tests that the [Client] correctly processes the response status line (e.g.
/// 'HTTP/1.1 200 OK\r\n').
///
/// Clients behavior varies considerably if the status line is not valid.
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

    test('complete', () async {
      httpServerChannel.sink.add('HTTP/1.1 201 Created');
      final response = await client.get(Uri.http(host, ''));
      expect(response.statusCode, 201);
      expect(response.reasonPhrase, 'Created');
    });

    test('no reason phrase', () async {
      httpServerChannel.sink.add('HTTP/1.1 201');
      final response = await client.get(Uri.http(host, ''));
      expect(response.statusCode, 201);
      // An empty Reason-Phrase is allowed according to RFC-2616. Any of these
      // interpretations seem reasonable.
      expect(response.reasonPhrase, anyOf(isNull, '', 'Created'));
    });
  });
}
