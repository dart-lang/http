// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NetLog', () {
    late HttpServer server;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          request.response.statusCode = 200;
          await request.response.close();
        });
    });

    tearDown(() {
      server.close();
    });

    test('startNetLogToFile and stopNetLog', () async {
      final engine = CronetEngine.build();
      final client = CronetClient.fromCronetEngine(engine, closeEngine: true);
      final tempDir = await Directory.systemTemp.createTemp('cronet_net_log');
      final logFile = File('${tempDir.path}/netlog.json');

      try {
        engine.startNetLogToFile(logFile.path, true);
        await client.get(Uri.parse('http://localhost:${server.port}'));
        engine.stopNetLog();

        expect(await logFile.exists(), isTrue);
        final content = await logFile.readAsString();
        expect(content, isNotEmpty);
        expect(content.trim(), startsWith('{'));
      } finally {
        client.close();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
