// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:test/test.dart';

/// Tests that the [Client] correctly implements streamed request body
/// uploading.
void testRequestBodyStreamed(Client client) {
  group('request body', () {
    test('client.send() with StreamedRequest', () async {
      // The client continuously streams data to the server until
      // instructed to stop (by setting `clientWriting` to `false`).
      // The server sets `serverWriting` to `false` after it has
      // already received some data.
      //
      // This ensures that the client supports streamed data sends.
      var lastReceived = 0;
      var clientWriting = true;
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await const LineSplitter()
              .bind(const Utf8Decoder().bind(request))
              .forEach((s) {
            lastReceived = int.parse(s.trim());
            if (lastReceived < 1000) {
              expect(clientWriting, true);
            } else {
              clientWriting = false;
            }
          });
          unawaited(request.response.close());
        });
      Stream<String> count() async* {
        var i = 0;
        while (clientWriting) {
          yield '${i++}\n';
          // Let the event loop run.
          await Future<void>.delayed(const Duration());
        }
      }

      final request =
          StreamedRequest('POST', Uri.http('localhost:${server.port}', ''));
      const Utf8Encoder()
          .bind(count())
          .listen(request.sink.add, onDone: request.sink.close);
      await client.send(request);

      expect(lastReceived, greaterThanOrEqualTo(1000));
      await server.close();
    });
  });
}
