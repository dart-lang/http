// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'request_cookies_server_vm.dart'
    if (dart.library.js_interop) 'request_cookies_server_web.dart';

/// Tests that the [Client] correctly sends headers in the request.
void testRequestCookies(Client client) async {
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

    test('set-cookie', () async {
      await client.get(Uri.http(host, ''), headers: {
        'Cookie': 'PHPSESSID=298zf09hf012fh2; csrftoken=u32t4o3tb3gg43; _gat=1'
      });

      final cookies = await httpServerQueue.next as List;
      expect(cookies,
          ['PHPSESSID=298zf09hf012fh2; csrftoken=u32t4o3tb3gg43; _gat=1']);
    });
  });
}
