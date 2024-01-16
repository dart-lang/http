// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'request_cookies_server_vm.dart'
    if (dart.library.js_interop) 'request_cookies_server_web.dart';

// The an HTTP header into [name, value].
final headerSplitter = RegExp(':[ \t]+');

/// Tests that the [Client] correctly sends "cookie" headers in the request.
///
/// If [canSendCookieHeaders] is `false` then tests that require that "cookie"
/// headers be sent by the client will not be run.
void testRequestCookies(Client client,
    {bool canSendCookieHeaders = false}) async {
  group('request cookies', () {
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.nextAsInt}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('one cookie', () async {
      await client
          .get(Uri.http(host, ''), headers: {'cookie': 'SID=298zf09hf012fh2'});

      final cookies = (await httpServerQueue.next as List).cast<String>();
      expect(cookies, hasLength(1));
      final [header, value] = cookies[0].split(headerSplitter);
      expect(header.toLowerCase(), 'cookie');
      expect(value, 'SID=298zf09hf012fh2');
    }, skip: canSendCookieHeaders ? false : 'cannot send cookie headers');

    test('multiple cookies semicolon separated', () async {
      await client.get(Uri.http(host, ''),
          headers: {'cookie': 'SID=298zf09hf012fh2; lang=en-US'});

      final cookies = (await httpServerQueue.next as List).cast<String>();
      expect(cookies, hasLength(1));
      final [header, value] = cookies[0].split(headerSplitter);
      expect(header.toLowerCase(), 'cookie');
      expect(value, 'SID=298zf09hf012fh2; lang=en-US');
    }, skip: canSendCookieHeaders ? false : 'cannot send cookie headers');
  });
}
