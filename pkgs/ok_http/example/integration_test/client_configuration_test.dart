// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:http/http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ok_http/ok_http.dart';
import 'package:test/test.dart';

void testTimeouts() {
  group('timeouts', () {
    group('call timeout', () {
      late HttpServer server;

      setUp(() async {
        server = (await HttpServer.bind('localhost', 0))
          ..listen((request) async {
            // Add a delay of `n` seconds for URI `http://localhost:port/n`
            final delay = int.parse(request.requestedUri.pathSegments.last);
            await Future<void>.delayed(Duration(seconds: delay));

            await request.drain<void>();
            await request.response.close();
          });
      });
      tearDown(() {
        server.close();
      });

      test('exceeded', () {
        final client = OkHttpClient(
          configuration: const OkHttpClientConfiguration(
            callTimeout: Duration(milliseconds: 500),
          ),
        );
        expect(
          () async {
            await client.get(Uri.parse('http://localhost:${server.port}/1'));
          },
          throwsA(
            isA<ClientException>().having(
              (exception) => exception.message,
              'message',
              startsWith('java.io.InterruptedIOException'),
            ),
          ),
        );
      });

      test('not exceeded', () async {
        final client = OkHttpClient(
          configuration: const OkHttpClientConfiguration(
            callTimeout: Duration(milliseconds: 1500),
          ),
        );
        final response = await client.send(
          Request(
            'GET',
            Uri.http('localhost:${server.port}', '1'),
          ),
        );

        expect(response.statusCode, 200);
        expect(response.contentLength, 0);
      });

      test('not set', () async {
        final client = OkHttpClient();

        expect(
          () async {
            await client.send(
              Request(
                'GET',
                Uri.http('localhost:${server.port}', '11'),
              ),
            );
          },
          throwsA(
            isA<ClientException>().having(
              (exception) => exception.message,
              'message',
              startsWith('java.net.SocketTimeoutException'),
            ),
          ),
        );
      });
    });
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testTimeouts();
}
