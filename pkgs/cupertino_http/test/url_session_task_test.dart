// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:test/test.dart';

void testURLSessionTask(
    URLSessionTask Function(URLSession session, Uri url) f) {
  group('task states', () {
    late HttpServer server;
    late URLSessionTask task;
    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write('Hello World');
          await request.response.close();
        });
      final session = URLSession.sharedSession();
      task = f(session, Uri.parse('http://localhost:${server.port}'));
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
        await Future<void>(() {});
      }
    });
  });

  group('task completed', () {
    late HttpServer server;
    late URLSessionTask task;
    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write('Hello World');
          await request.response.close();
        });
      final session = URLSession.sharedSession();
      task = session.dataTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')))
        ..resume();

      while (task.state != URLSessionTaskState.urlSessionTaskStateCompleted) {
        // Let the event loop run.
        await Future<void>(() {});
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

    test('taskIdentifier', () {
      task.taskIdentifier; // Just verify that there is no crash.
    });

    test('toString', () {
      task.toString(); // Just verify that there is no crash.
    });
  });
}

void main() {
  group('data task', () {
    testURLSessionTask(
        (session, uri) => session.dataTaskWithRequest(URLRequest.fromUrl(uri)));
  });

  group('download task', () {
    testURLSessionTask((session, uri) =>
        session.downloadTaskWithRequest(URLRequest.fromUrl(uri)));
  });
}
