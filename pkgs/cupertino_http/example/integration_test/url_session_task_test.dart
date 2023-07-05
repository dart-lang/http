// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

void testWebSocketTask() {
  group('websocket', () {
    late HttpServer server;
    int? lastCloseCode;
    String? lastCloseReason;

    setUp(() async {
      lastCloseCode = null;
      lastCloseReason = null;
      server = await HttpServer.bind('localhost', 0)
        ..listen((request) {
          if (request.uri.path.endsWith('error')) {
            request.response.statusCode = 500;
            request.response.close();
          } else {
            WebSocketTransformer.upgrade(request)
                .then((websocket) => websocket.listen((event) {
                      final code = request.uri.queryParameters['code'];
                      final reason = request.uri.queryParameters['reason'];

                      websocket.add(event);
                      if (!request.uri.queryParameters.containsKey('noclose')) {
                        websocket.close(
                            code == null ? null : int.parse(code), reason);
                      }
                    }, onDone: () {
                      lastCloseCode = websocket.closeCode;
                      lastCloseReason = websocket.closeReason;
                    }));
          }
        });
    });

    tearDown(() async {
      await server.close();
    });

    test('background session', () {
      final session = URLSession.sessionWithConfiguration(
          URLSessionConfiguration.backgroundSession('background'));
      expect(
          () => session.webSocketTaskWithRequest(URLRequest.fromUrl(
              Uri.parse('ws://localhost:${server.port}/?noclose'))),
          throwsUnsupportedError);
    });

    test('client code and reason', () async {
      final session = URLSession.sharedSession();
      final task = session.webSocketTaskWithRequest(URLRequest.fromUrl(
          Uri.parse('ws://localhost:${server.port}/?noclose')))
        ..resume();
      await task
          .sendMessage(URLSessionWebSocketMessage.fromString('Hello World!'));
      await task.receiveMessage();
      task.cancelWithCloseCode(4998, Data.fromList('Bye'.codeUnits));

      // Allow the server to run and save the close code.
      while (lastCloseCode == null) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(lastCloseCode, 4998);
      expect(lastCloseReason, 'Bye');
    });

    test('server code and reason', () async {
      final session = URLSession.sharedSession();
      final task = session.webSocketTaskWithRequest(URLRequest.fromUrl(
          Uri.parse('ws://localhost:${server.port}/?code=4999&reason=fun')))
        ..resume();
      await task
          .sendMessage(URLSessionWebSocketMessage.fromString('Hello World!'));
      await task.receiveMessage();
      await expectLater(task.receiveMessage(),
          throwsA(isA<Error>().having((e) => e.code, 'code', 57 // NOT_CONNECTED
              )));

      expect(task.closeCode, 4999);
      expect(task.closeReason!.bytes, 'fun'.codeUnits);
      task.cancel();
    });

    test('data message', () async {
      final session = URLSession.sharedSession();
      final task = session.webSocketTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('ws://localhost:${server.port}')))
        ..resume();
      await task.sendMessage(
          URLSessionWebSocketMessage.fromData(Data.fromList([1, 2, 3])));
      final receivedMessage = await task.receiveMessage();
      expect(receivedMessage.type,
          URLSessionWebSocketMessageType.urlSessionWebSocketMessageTypeData);
      expect(receivedMessage.data!.bytes, [1, 2, 3]);
      expect(receivedMessage.string, null);
      task.cancel();
    });

    test('text message', () async {
      final session = URLSession.sharedSession();
      final task = session.webSocketTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('ws://localhost:${server.port}')))
        ..resume();
      await task
          .sendMessage(URLSessionWebSocketMessage.fromString('Hello World!'));
      final receivedMessage = await task.receiveMessage();
      expect(receivedMessage.type,
          URLSessionWebSocketMessageType.urlSessionWebSocketMessageTypeString);
      expect(receivedMessage.data, null);
      expect(receivedMessage.string, 'Hello World!');
      task.cancel();
    });

    test('send failure', () async {
      final session = URLSession.sharedSession();
      final task = session.webSocketTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('ws://localhost:${server.port}/error')))
        ..resume();
      await expectLater(
          task.sendMessage(
              URLSessionWebSocketMessage.fromString('Hello World!')),
          throwsA(isA<Error>().having(
              (e) => e.code, 'code', -1011 // NSURLErrorBadServerResponse
              )));
      task.cancel();
    });

    test('receive failure', () async {
      final session = URLSession.sharedSession();
      final task = session.webSocketTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('ws://localhost:${server.port}')))
        ..resume();
      await task
          .sendMessage(URLSessionWebSocketMessage.fromString('Hello World!'));
      await task.receiveMessage();
      await expectLater(task.receiveMessage(),
          throwsA(isA<Error>().having((e) => e.code, 'code', 57 // NOT_CONNECTED
              )));
      task.cancel();
    });
  });
}

void testURLSessionTaskCommon(
    URLSessionTask Function(URLSession session, Uri url) f,
    {bool suspendedAfterCancel = false}) {
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
      if (suspendedAfterCancel) {
        expect(task.state, URLSessionTaskState.urlSessionTaskStateSuspended);
      } else {
        expect(task.state, URLSessionTaskState.urlSessionTaskStateCanceling);
      }
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
            ..httpBody = Data.fromList([1, 2, 3]))
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
    testURLSessionTaskCommon(
        (session, uri) => session.dataTaskWithRequest(URLRequest.fromUrl(uri)));
  });

  group('download task', () {
    testURLSessionTaskCommon((session, uri) =>
        session.downloadTaskWithRequest(URLRequest.fromUrl(uri)));
  });

  group('websocket task', () {
    testURLSessionTaskCommon(
        (session, uri) =>
            session.webSocketTaskWithRequest(URLRequest.fromUrl(uri)),
        suspendedAfterCancel: true);
  });

  testWebSocketTask();
}
