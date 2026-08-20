// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:test/test.dart';

/// The failure is a race between the callback and the isolate teardown, so it
/// takes a few attempts to hit reliably.
const _isolateCount = 20;

const _responseDelay = Duration(milliseconds: 500);
const _callbackGracePeriod = Duration(seconds: 1);

/// Selects the child process; `package:test` rejects a `main` with arguments.
const _childMarker = 'CUPERTINO_HTTP_ISOLATE_SHUTDOWN_CHILD';

/// A delegate callback that arrives after its isolate is gone aborts the VM,
/// which would take the test runner down with it, hence the child process.
Future<void> _shutDownIsolatesWithRequestsInFlight() async {
  final server = await HttpServer.bind('localhost', 0);
  server.listen((request) async {
    await Future<void>.delayed(_responseDelay);
    await request.response.close();
  });
  final uri = Uri.parse('http://localhost:${server.port}');

  for (var i = 0; i < _isolateCount; ++i) {
    await Isolate.run(() {
      CupertinoClient.defaultSessionConfiguration().get(uri).ignore();
    });
  }

  await Future<void>.delayed(_callbackGracePeriod);
  await server.close();
}

void main() {
  if (Platform.environment.containsKey(_childMarker)) {
    unawaited(_shutDownIsolatesWithRequestsInFlight());
    return;
  }

  // The generous timeout is for the native assets, which the child builds
  // itself when the cache is cold.
  test(
    'isolate shut down with a request in flight',
    () async {
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'test/isolate_shutdown_test.dart'],
        environment: {_childMarker: '1'},
      );
      printOnFailure(result.stderr as String);
      expect(result.exitCode, 0);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
