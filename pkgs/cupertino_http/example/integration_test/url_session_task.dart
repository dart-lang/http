// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';
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
          MutableURLRequest.fromUrl(
              Uri.parse('http://localhost:${server.port}/mypath'))
            ..httpMethod = 'POST'
            ..httpBody = Data.fromUint8List(Uint8List.fromList([1, 2, 3])))
        ..prefersIncrementalDelivery = false
        ..priority = 0.2
        ..taskDescription = 'my task description'
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

    test('priority', () async {
      expect(task.priority, inInclusiveRange(0.19, 0.21));
    });

    test('current request', () async {
      expect(task.currentRequest!.url!.path, '/mypath');
    });

    test('original request', () async {
      expect(task.originalRequest!.url!.path, '/mypath');
    });

    test('has response', () async {
      expect(task.response, isA<HTTPURLResponse>());
    });

    test('no error', () async {
      expect(task.error, null);
    });

    test('countOfBytesExpectedToReceive - no content length set', () async {
      expect(task.countOfBytesExpectedToReceive, -1);
    });

    test('countOfBytesReceived', () async {
      expect(task.countOfBytesReceived, 11);
    });

    test('countOfBytesExpectedToSend', () async {
      expect(task.countOfBytesExpectedToSend, 3);
    });

    test('countOfBytesSent', () async {
      expect(task.countOfBytesSent, 3);
    });

    test('taskDescription', () {
      expect(task.taskDescription, 'my task description');
    });

    test('taskIdentifier', () {
      task.taskIdentifier; // Just verify that there is no crash.
    });

    test('prefersIncrementalDelivery', () {
      expect(task.prefersIncrementalDelivery, false);
    });

    test('toString', () {
      task.toString(); // Just verify that there is no crash.
    });
  });

  group('task failed', () {
    late URLSessionTask task;
    setUp(() async {
      final session = URLSession.sharedSession();
      task = session.dataTaskWithRequest(
          MutableURLRequest.fromUrl(Uri.parse('http://notarealserver')))
        ..resume();

      while (task.state != URLSessionTaskState.urlSessionTaskStateCompleted) {
        // Let the event loop run.
        await Future<void>(() {});
      }
    });
    tearDown(() {
      task.cancel();
    });

    test('no response', () async {
      expect(task.response, null);
    });

    test('no error', () async {
      expect(task.error!.code, -1003); // CannotFindHost
    });

    test('toString', () {
      task.toString(); // Just verify that there is no crash.
    });
  });

  group('task redirect', () {
    late HttpServer server;
    late URLSessionTask task;
    setUp(() async {
      // The task will request http://localhost:XXX/launch, which will be
      // redirected to http://localhost:XXX/landed.
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          if (request.requestedUri.path != '/landed') {
            await request.response.redirect(Uri(path: '/landed'));
            return;
          }
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write('Hello World');
          await request.response.close();
        });
      final session = URLSession.sharedSession();
      task = session.dataTaskWithRequest(MutableURLRequest.fromUrl(
          Uri.parse('http://localhost:${server.port}/launch')))
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

    test('current request', () async {
      expect(task.currentRequest!.url!.path, '/landed');
    });

    test('original request', () async {
      expect(task.originalRequest!.url!.path, '/launch');
    });

    test('toString', () {
      task.toString(); // Just verify that there is no crash.
    });
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('data task', () {
    testURLSessionTask(
        (session, uri) => session.dataTaskWithRequest(URLRequest.fromUrl(uri)));
  });

  group('download task', () {
    testURLSessionTask((session, uri) =>
        session.downloadTaskWithRequest(URLRequest.fromUrl(uri)));
  });
}
