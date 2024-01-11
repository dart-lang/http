// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'response_cookies_server_vm.dart'
    if (dart.library.js_interop) 'response_cookies_server_web.dart';

/// Tests that the [Client] correctly receives "set-cookie-headers"
///
/// If [canReceiveSetCookieHeaders] is `false` then tests that require that
/// "set-cookie" headers be received by the client will not be run.
void testResponseCookies(Client client,
    {required bool canReceiveSetCookieHeaders}) async {
  group('response cookies', () {
    late String host;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.nextAsInt}';
    });

    test('single session cookie', () async {
      httpServerChannel.sink.add(['Set-Cookie: SID=1231AB3']);
      final response = await client.get(Uri.http(host, ''));

      expect(response.headers['set-cookie'], 'SID=1231AB3');
    },
        skip: canReceiveSetCookieHeaders
            ? false
            : 'cannot receive set-cookie headers');

    test('multiple session cookies', () async {
      // RFC-2616 4.2 says:
      // "The field value MAY be preceded by any amount of LWS, though a single
      // SP is preferred." and
      // "The field-content does not include any leading or trailing LWS ..."
      httpServerChannel.sink.add([
        'Set-Cookie: SID=1231AB3',
        ['Set-Cookie: lang=en_US']
      ]);
      final response = await client.get(Uri.http(host, ''));

      expect(
          response.headers['set-cookie'],
          matches(r'SID=1231AB3'
              r'[ \t]*,[ \t]*'
              r'lang=en_US'));
    },
        skip: canReceiveSetCookieHeaders
            ? false
            : 'cannot receive set-cookie headers');

    test('permanent cookie with expires', () async {
      httpServerChannel.sink
          .add(['Set-Cookie: id=a3fWa; Expires=Wed, 10 Jan 2024 07:28:00 GMT']);
      final response = await client.get(Uri.http(host, ''));

      expect(response.headers['set-cookie'],
          'id=a3fWa; Expires=Wed, 10 Jan 2024 07:28:00 GMT');
    },
        skip: canReceiveSetCookieHeaders
            ? false
            : 'cannot receive set-cookie headers');

    test('multiple permanent cookies with expires', () async {
      // RFC-2616 4.2 says:
      // "The field value MAY be preceded by any amount of LWS, though a single
      // SP is preferred." and
      // "The field-content does not include any leading or trailing LWS ..."
      httpServerChannel.sink.add([
        'Set-Cookie: id=a3fWa; Expires=Wed, 10 Jan 2024 07:28:00 GMT',
        'Set-Cookie: id=2fasd; Expires=Wed, 21 Oct 2025 07:28:00 GMT'
      ]);
      final response = await client.get(Uri.http(host, ''));

      expect(
          response.headers['set-cookie'],
          matches(r'id=a3fWa; Expires=Wed, 10 Jan 2024 07:28:00 GMT'
              r'[ \t]*,[ \t]*'
              r'id=2fasd; Expires=Wed, 21 Oct 2025 07:28:00 GMT'));
    },
        skip: canReceiveSetCookieHeaders
            ? false
            : 'cannot receive set-cookie headers');
  });
}
