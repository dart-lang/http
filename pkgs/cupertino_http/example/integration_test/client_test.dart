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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('defaultSessionConfiguration', () {
    testClient(CupertinoClient.defaultSessionConfiguration());
  });
  group('fromSessionConfiguration', () {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration();
    testClient(CupertinoClient.fromSessionConfiguration(config));
  });
}
