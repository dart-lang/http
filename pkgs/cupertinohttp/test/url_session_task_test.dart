// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';
import 'package:cupertinohttp/cupertinohttp.dart';

void main() {
  group('task states', () {
    late HttpServer server;
    late URLSessionTask task;
    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          request.drain();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write("Hello World");
          await request.response.close();
        });
      final session = URLSession.sharedSession();
      task = session.dataTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')));
    });
    tearDown(() {
      task.cancel();
      server.close();
    });
    test('starts suspended', () {
      expect(task.state, URLSessionTaskState.urlSessionTaskStateSuspended);
      expect(task.response, null);
      task.toString(); // Just verify that there is no crash.
    });

    test('resume to running', () {
      task.resume();
      expect(task.state, URLSessionTaskState.urlSessionTaskStateRunning);
      expect(task.response, null);
      task.toString(); // Just verify that there is no crash.
    });

    test('cancel', () {
      task.cancel();
      expect(task.state, URLSessionTaskState.urlSessionTaskStateCanceling);
      expect(task.response, null);
      task.toString(); // Just verify that there is no crash.
    });

    test('completed', () async {
      task.resume();
      while (task.state != URLSessionTaskState.urlSessionTaskStateCompleted) {
        // Let the event loop run.
        await Future.delayed(const Duration());
      }
    });
  });

  group('task completed', () {
    late HttpServer server;
    late URLSessionTask task;
    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          request.drain();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write("Hello World");
          await request.response.close();
        });
      final session = URLSession.sharedSession();
      task = session.dataTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')));

      task.resume();
      while (task.state != URLSessionTaskState.urlSessionTaskStateCompleted) {
        // Let the event loop run.
        await Future.delayed(const Duration());
      }
    });
    tearDown(() {
      task.cancel();
      server.close();
    });

    test('has response', () async {
      expect(task.response, isA<HTTPURLResponse>());
    });

    test('countOfBytesExpectedToReceive - no content length set', () async {
      expect(task.countOfBytesExpectedToReceive, -1);
    });

    test('countOfBytesReceived', () async {
      expect(task.countOfBytesReceived, 11);
    });

    test('taskIdentifider', () {
      task.taskIdentifider; // Just verify that there is no crash.
    });

    test('toString', () {
      task.toString(); // Just verify that there is no crash.
    });
  });
}
