// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:test/test.dart';

/// Tests that the [Client] correctly implements HTTP responses with bodies.
///
/// If [canStreamResponseBody] is `false` then tests that assume that the
/// [Client] supports receiving HTTP responses with unbounded body sizes will
/// be skipped
void testResponseBody(Client client,
    {bool canStreamResponseBody = true}) async {
  group('response body', () {
    test('small response with content length', () async {
      const message = 'Hello World!';
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write(message);
          await request.response.close();
        });
      final response =
          await client.get(Uri.parse('http://localhost:${server.port}'));
      expect(response.body, message);
      expect(response.bodyBytes, message.codeUnits);
      expect(response.contentLength, message.length);
      expect(response.headers['content-type'], 'text/plain');
      await server.close();
    });

    test('small response streamed without content length', () async {
      const message = 'Hello World!';
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write(message);
          await request.response.close();
        });
      final request =
          Request('GET', Uri.parse('http://localhost:${server.port}'));
      final response = await client.send(request);
      expect(await response.stream.bytesToString(), message);
      expect(response.contentLength, null);
      expect(response.headers['content-type'], 'text/plain');
      await server.close();
    });

    test('large response streamed without content length', () async {
      // The server continuously streams data to the client until
      // instructed to stop (by setting `serverWriting` to `false`).
      // The client sets `serverWriting` to `false` after it has
      // already received some data.
      //
      // This ensures that the client supports streamed responses.
      var serverWriting = false;
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          request.response.headers.set('Content-Type', 'text/plain');
          serverWriting = true;
          for (var i = 0; serverWriting; ++i) {
            request.response.write('$i\n');
            await request.response.flush();
            // Let the event loop run.
            await Future<void>.delayed(const Duration());
          }
          await request.response.close();
        });
      final request =
          Request('GET', Uri.parse('http://localhost:${server.port}'));
      final response = await client.send(request);
      var lastReceived = 0;
      await const LineSplitter()
          .bind(const Utf8Decoder().bind(response.stream))
          .forEach((s) {
        lastReceived = int.parse(s.trim());
        if (lastReceived < 1000) {
          expect(serverWriting, true);
        } else {
          serverWriting = false;
        }
      });
      expect(response.headers['content-type'], 'text/plain');
      expect(lastReceived, greaterThanOrEqualTo(1000));
      await server.close();
    }, skip: canStreamResponseBody ? false : 'does not stream response bodies');
  });
}
