// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'multipart_server_vm.dart'
    if (dart.library.js_interop) 'multipart_server_web.dart';

/// Tests that the [Client] correctly sends [MultipartRequest].
void testMultipartRequests(Client client) async {
  group('multipart requests', () {
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.nextAsInt}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('attached file', () async {
      final request = MultipartRequest('POST', Uri.http(host, ''));

      request.files.add(MultipartFile.fromString('file1', 'Hello World'));

      await client.send(request);
      final (headers, body) =
          await httpServerQueue.next as (Map<String, List<String>>, String);
      expect(headers['content-length']!.single, '${request.contentLength}');
      expect(headers['content-type']!.single,
          startsWith('multipart/form-data; boundary='));
      expect(body, contains('''content-type: text/plain; charset=utf-8\r
content-disposition: form-data; name="file1"\r
\r
Hello World'''));
    });
  });
}
