// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:test/test.dart';

/// The failure is a race between the callback and the isolate teardown, so it
/// takes a few attempts to hit reliably.
const _isolateCount = 20;

const _responseDelay = Duration(milliseconds: 500);

/// Allows time for the server to respond and native callbacks to fire against
/// the dead isolates before the test exits.
const _callbackGracePeriod = Duration(seconds: 1);

void main() {
  test('isolate shut down with a request in flight', () async {
    final server = await HttpServer.bind('localhost', 0);
    addTearDown(server.close);
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
  });
}
