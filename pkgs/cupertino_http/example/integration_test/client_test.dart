// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:integration_test/integration_test.dart';

void testClient(Client client) {
  group('client tests', () {
    late HttpServer server;
    late Uri uri;
    late List<int> serverHash;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          var hashSink = AccumulatorSink<Digest>();
          final hashConverter = sha1.startChunkedConversion(hashSink);
          await request.listen(hashConverter.add).asFuture<void>();
          hashConverter.close();
          serverHash = hashSink.events.single.bytes;
          await request.response.close();
        });
      uri = Uri.http('localhost:${server.port}');
    });
    tearDown(() {
      server.close();
    });

    test('large single item stream', () async {
      // This tests that `CUPHTTPStreamToNSInputStreamAdapter` correctly
      // handles calls to `read:maxLength:` where the maximum length
      // is smaller than the amount of data in the buffer.
      final size = (Platform.isIOS ? 10 : 100) * 1024 * 1024;
      final data = Uint8List(size);
      for (var i = 0; i < data.length; ++i) {
        data[i] = i % 256;
      }
      final request = StreamedRequest('POST', uri);
      request.sink.add(data);
      unawaited(request.sink.close());
      await client.send(request);
      expect(serverHash, sha1.convert(data).bytes);
    });
  });
}

void testStreamingBehavior() {
  group('streaming behavior', () {
    late HttpServer server;
    late CupertinoClient client;

    setUp(() async {
      server = await HttpServer.bind('localhost', 0);
      client = CupertinoClient.fromSharedSession(URLSession.sharedSession());
    });

    tearDown(() async {
      client.close();
      await server.close();
    });

    test('receives response in multiple chunks', () async {
      const chunkCount = 10;
      const chunkSize = 65536; // Match StreamingTask buffer size
      server.listen((request) async {
        for (var i = 0; i < chunkCount; i++) {
          request.response.add(Uint8List(chunkSize));
          // Small delay to allow chunked delivery
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await request.response.close();
      });

      final request = Request('GET', Uri.http('localhost:${server.port}', '/'));
      final response = await client.send(request);

      var receivedChunks = 0;
      await for (final _ in response.stream) {
        receivedChunks++;
      }
      // Should receive multiple chunks, not a single buffered response
      expect(receivedChunks, greaterThan(1));
    });

    test('POST request body is sent correctly', () async {
      late List<int> receivedBody;
      server.listen((request) async {
        receivedBody =
            await request.fold<List<int>>([], (a, b) => a..addAll(b));
        request.response.statusCode = 200;
        await request.response.close();
      });

      final body = List.generate(10000, (i) => i % 256);
      await client.post(
        Uri.http('localhost:${server.port}', '/'),
        body: body,
      );
      expect(receivedBody, body);
    });

    test('StreamedRequest body is sent correctly', () async {
      var hashSink = AccumulatorSink<Digest>();
      final hashConverter = sha1.startChunkedConversion(hashSink);

      server.listen((request) async {
        await request.listen(hashConverter.add).asFuture<void>();
        hashConverter.close();
        await request.response.close();
      });

      const size = 1024 * 1024; // 1MB
      final data = Uint8List(size);
      for (var i = 0; i < data.length; ++i) {
        data[i] = i % 256;
      }

      final request =
          StreamedRequest('POST', Uri.http('localhost:${server.port}', '/'));
      request.sink.add(data);
      unawaited(request.sink.close());
      await client.send(request);

      expect(hashSink.events.single.bytes, sha1.convert(data).bytes);
    });

    test('response stream cancellation', () async {
      var bytesWritten = 0;
      server.listen((request) async {
        for (var i = 0; i < 100; i++) {
          request.response.add(Uint8List(10000));
          bytesWritten += 10000;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await request.response.close();
      });

      final request = Request('GET', Uri.http('localhost:${server.port}', '/'));
      final response = await client.send(request);

      var chunksReceived = 0;
      await for (final _ in response.stream) {
        chunksReceived++;
        if (chunksReceived >= 3) break; // Cancel by breaking iteration
      }

      // Should have stopped early
      expect(chunksReceived, 3);
      // Give server time to notice cancellation
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Server shouldn't have written all data
      expect(bytesWritten, lessThan(100 * 10000));
    });
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('defaultSessionConfiguration', () {
    testClient(CupertinoClient.defaultSessionConfiguration());
  });
  group('fromSessionConfiguration', () {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration();
    testClient(CupertinoClient.fromSessionConfiguration(config));
  });
  group('fromSharedSession', () {
    testClient(CupertinoClient.fromSharedSession(URLSession.sharedSession()));
    testStreamingBehavior();
  });
}
