// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

void testOnComplete(URLSessionConfiguration config) {
  group('onComplete', () {
    late HttpServer server;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write('Hello World');
          await request.response.close();
        });
    });
    tearDown(() {
      server.close();
    });

    test('success', () async {
      final c = Completer<void>();
      Error? actualError;
      late URLSession actualSession;
      late URLSessionTask actualTask;

      final session =
          URLSession.sessionWithConfiguration(config, onComplete: (s, t, e) {
        actualSession = s;
        actualTask = t;
        actualError = e;
        c.complete();
      });

      final task = session.dataTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')))
        ..resume();
      await c.future;

      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualError, null);
    });

    test('bad host', () async {
      final c = Completer<void>();
      Error? actualError;
      late URLSession actualSession;
      late URLSessionTask actualTask;

      final session =
          URLSession.sessionWithConfiguration(config, onComplete: (s, t, e) {
        actualSession = s;
        actualTask = t;
        actualError = e;
        c.complete();
      });

      final task = session.dataTaskWithRequest(
          URLRequest.fromUrl(Uri.https('does-not-exist', '')))
        ..resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(
          actualError!.code,
          anyOf(
            -1001, // kCFURLErrorTimedOut
            -1003, // kCFURLErrorCannotFindHost
          ));
    });
  });
}

void testOnResponse(URLSessionConfiguration config) {
  group('onResponse', () {
    late HttpServer server;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write('Hello World');
          await request.response.close();
        });
    });
    tearDown(() {
      server.close();
    });

    test('success', () async {
      final c = Completer<void>();
      late HTTPURLResponse actualResponse;
      late URLSession actualSession;
      late URLSessionTask actualTask;

      final session =
          URLSession.sessionWithConfiguration(config, onResponse: (s, t, r) {
        actualSession = s;
        actualTask = t;
        actualResponse = r as HTTPURLResponse;
        c.complete();
        return URLSessionResponseDisposition.urlSessionResponseAllow;
      });

      final task = session.dataTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')))
        ..resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualResponse.statusCode, 200);
    });

    test('bad host', () async {
      // `onResponse` should not be called because there was no valid response.
      final c = Completer<void>();
      var called = false;

      final session = URLSession.sessionWithConfiguration(config,
          onComplete: (session, task, error) => c.complete(),
          onResponse: (s, t, r) {
            called = true;
            return URLSessionResponseDisposition.urlSessionResponseAllow;
          });

      session
          .dataTaskWithRequest(
              URLRequest.fromUrl(Uri.https('does-not-exist', '')))
          .resume();
      await c.future;
      expect(called, false);
    });
  });
}

void testOnData(URLSessionConfiguration config) {
  group('onData', () {
    late HttpServer server;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write('Hello World');
          await request.response.close();
        });
    });
    tearDown(() {
      server.close();
    });

    test('success', () async {
      final c = Completer<void>();
      final actualData = MutableData.empty();
      late URLSession actualSession;
      late URLSessionTask actualTask;

      final session = URLSession.sessionWithConfiguration(config,
          onComplete: (s, t, r) => c.complete(),
          onData: (s, t, d) {
            actualSession = s;
            actualTask = t;
            actualData.appendBytes(d.bytes);
          });

      final task = session.dataTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')))
        ..resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualData.bytes, 'Hello World'.codeUnits);
    });
  });
}

void testOnFinishedDownloading(URLSessionConfiguration config) {
  group('onFinishedDownloading', () {
    late HttpServer server;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write('Hello World');
          await request.response.close();
        });
    });
    tearDown(() {
      server.close();
    });

    test('success', () async {
      final c = Completer<void>();
      late URLSession actualSession;
      late URLSessionDownloadTask actualTask;
      late String actualContent;

      final session = URLSession.sessionWithConfiguration(config,
          onComplete: (s, t, r) => c.complete(),
          onFinishedDownloading: (s, t, uri) {
            actualSession = s;
            actualTask = t;
            actualContent = File.fromUri(uri).readAsStringSync();
          });

      final task = session.downloadTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')))
        ..resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualContent, 'Hello World');
    });
  });
}

void testOnRedirect(URLSessionConfiguration config) {
  group('onRedirect', () {
    late HttpServer redirectServer;

    setUp(() async {
      //        URI |  Redirects TO
      // ===========|==============
      //   ".../10" |       ".../9"
      //    ".../9" |       ".../8"
      //        ... |           ...
      //    ".../1" |           "/"
      //        "/" |  <no redirect>
      redirectServer = await HttpServer.bind('localhost', 0)
        ..listen((request) async {
          if (request.requestedUri.pathSegments.isEmpty) {
            unawaited(request.response.close());
          } else {
            final n = int.parse(request.requestedUri.pathSegments.last);
            final nextPath = n - 1 == 0 ? '' : '${n - 1}';
            unawaited(request.response.redirect(Uri.parse(
                'http://localhost:${redirectServer.port}/$nextPath')));
          }
        });
    });
    tearDown(() {
      redirectServer.close();
    });

    test('disallow redirect', () async {
      final session = URLSession.sessionWithConfiguration(config,
          onRedirect:
              (redirectSession, redirectTask, redirectResponse, newRequest) =>
                  null);
      final c = Completer<void>();
      HTTPURLResponse? response;
      Error? error;

      session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${redirectServer.port}/100')),
          (d, r, e) {
        response = r;
        error = e;
        c.complete();
      }).resume();
      await c.future;

      expect(response!.statusCode, 302);
      expect(response!.allHeaderFields['Location'],
          'http://localhost:${redirectServer.port}/99');
      expect(error, null);
    });

    test('use preposed redirect request', () async {
      final session = URLSession.sessionWithConfiguration(config,
          onRedirect:
              (redirectSession, redirectTask, redirectResponse, newRequest) =>
                  newRequest);
      final c = Completer<void>();
      HTTPURLResponse? response;
      Error? error;

      session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${redirectServer.port}/1')),
          (d, r, e) {
        response = r;
        error = e;
        c.complete();
      }).resume();
      await c.future;

      expect(response!.statusCode, 200);
      expect(error, null);
    });

    test('use custom redirect request', () async {
      final session = URLSession.sessionWithConfiguration(
        config,
        onRedirect: (redirectSession, redirectTask, redirectResponse,
                newRequest) =>
            URLRequest.fromUrl(
                Uri.parse('http://localhost:${redirectServer.port}/')),
      );
      final c = Completer<void>();
      HTTPURLResponse? response;
      Error? error;

      session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${redirectServer.port}/100')),
          (d, r, e) {
        response = r;
        error = e;
        c.complete();
      }).resume();
      await c.future;

      expect(response!.statusCode, 200);
      expect(error, null);
    });

    test('exception in http redirection', () async {
      final session = URLSession.sessionWithConfiguration(
        config,
        onRedirect:
            (redirectSession, redirectTask, redirectResponse, newRequest) {
          throw UnimplementedError();
        },
      );
      final c = Completer<void>();
      HTTPURLResponse? response;
      // ignore: unused_local_variable
      Error? error;

      session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${redirectServer.port}/100')),
          (d, r, e) {
        response = r;
        error = e;
        c.complete();
      }).resume();
      await c.future;

      expect(response!.statusCode, 302);
      // TODO(https://github.com/dart-lang/ffigen/issues/386): Check that the
      // error is set.
    }, skip: 'Error not set for redirect exceptions.');

    test('3 redirects', () async {
      var redirectCounter = 0;
      final session = URLSession.sessionWithConfiguration(
        config,
        onRedirect:
            (redirectSession, redirectTask, redirectResponse, newRequest) {
          expect(redirectResponse.statusCode, 302);
          switch (redirectCounter) {
            case 0:
              expect(redirectResponse.allHeaderFields['Location'],
                  'http://localhost:${redirectServer.port}/2');
              expect(newRequest.url,
                  Uri.parse('http://localhost:${redirectServer.port}/2'));
              break;
            case 1:
              expect(redirectResponse.allHeaderFields['Location'],
                  'http://localhost:${redirectServer.port}/1');
              expect(newRequest.url,
                  Uri.parse('http://localhost:${redirectServer.port}/1'));
              break;
            case 2:
              expect(redirectResponse.allHeaderFields['Location'],
                  'http://localhost:${redirectServer.port}/');
              expect(newRequest.url,
                  Uri.parse('http://localhost:${redirectServer.port}/'));
              break;
          }
          ++redirectCounter;
          return newRequest;
        },
      );
      final c = Completer<void>();
      HTTPURLResponse? response;
      Error? error;

      session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${redirectServer.port}/3')),
          (d, r, e) {
        response = r;
        error = e;
        c.complete();
      }).resume();
      await c.future;

      expect(response!.statusCode, 200);
      expect(error, null);
    });

    test('allow too many redirects', () async {
      // The Foundation URL Loading System limits the number of redirects
      // even when a redirect delegate is present and allows the redirect.
      final session = URLSession.sessionWithConfiguration(
        config,
        onRedirect:
            (redirectSession, redirectTask, redirectResponse, newRequest) =>
                newRequest,
      );
      final c = Completer<void>();
      HTTPURLResponse? response;
      Error? error;

      session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${redirectServer.port}/100')),
          (d, r, e) {
        response = r;
        error = e;
        c.complete();
      }).resume();
      await c.future;

      expect(response, null);
      expect(error!.code, -1007); // kCFURLErrorHTTPTooManyRedirects
    });
  });
}

void testOnWebSocketTaskOpened(URLSessionConfiguration config) {
  group('onWebSocketTaskOpened', () {
    late HttpServer server;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          if (request.requestedUri.queryParameters.containsKey('error')) {
            request.response.statusCode = 500;
            unawaited(request.response.close());
            return;
          }
          final webSocket = await WebSocketTransformer.upgrade(
            request,
            protocolSelector: (l) => 'myprotocol',
          );
          await webSocket.close();
        });
    });
    tearDown(() {
      server.close();
    });

    test('with protocol', () async {
      final c = Completer<void>();
      late String? actualProtocol;
      late URLSession actualSession;
      late URLSessionWebSocketTask actualTask;

      final session = URLSession.sessionWithConfiguration(config,
          onWebSocketTaskOpened: (s, t, p) {
        actualSession = s;
        actualTask = t;
        actualProtocol = p;
        c.complete();
      });

      final request = MutableURLRequest.fromUrl(
          Uri.parse('http://localhost:${server.port}'))
        ..setValueForHttpHeaderField('Sec-WebSocket-Protocol', 'myprotocol');

      final task = session.webSocketTaskWithRequest(request)..resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualProtocol, 'myprotocol');
    });

    test('without protocol', () async {
      final c = Completer<void>();
      late String? actualProtocol;
      late URLSession actualSession;
      late URLSessionWebSocketTask actualTask;

      final session = URLSession.sessionWithConfiguration(config,
          onWebSocketTaskOpened: (s, t, p) {
        actualSession = s;
        actualTask = t;
        actualProtocol = p;
        c.complete();
      });

      final request = MutableURLRequest.fromUrl(
          Uri.parse('http://localhost:${server.port}'));
      final task = session.webSocketTaskWithRequest(request)..resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualProtocol, null);
    });

    test('server failure', () async {
      final c = Completer<void>();
      var onWebSocketTaskOpenedCalled = false;

      final session = URLSession.sessionWithConfiguration(config,
          onWebSocketTaskOpened: (s, t, p) {
        onWebSocketTaskOpenedCalled = true;
      }, onComplete: (s, t, e) {
        expect(e, isNotNull);
        c.complete();
      });

      final request = MutableURLRequest.fromUrl(
          Uri.parse('http://localhost:${server.port}?error=1'));
      session.webSocketTaskWithRequest(request).resume();
      await c.future;
      expect(onWebSocketTaskOpenedCalled, false);
    });
  });
}

void testOnWebSocketTaskClosed(URLSessionConfiguration config) {
  group('testOnWebSocketTaskClosed', () {
    late HttpServer server;
    late int? serverCode;
    late String? serverReason;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          if (request.requestedUri.queryParameters.containsKey('error')) {
            request.response.statusCode = 500;
            unawaited(request.response.close());
            return;
          }
          final webSocket = await WebSocketTransformer.upgrade(
            request,
          );
          await webSocket.close(serverCode, serverReason);
        });
    });
    tearDown(() {
      server.close();
    });

    test('close no code', () async {
      final c = Completer<void>();
      late int actualCloseCode;
      late String? actualReason;
      late URLSession actualSession;
      late URLSessionWebSocketTask actualTask;

      serverCode = null;
      serverReason = null;

      final session = URLSession.sessionWithConfiguration(config,
          onWebSocketTaskOpened: (session, task, protocol) {},
          onWebSocketTaskClosed: (session, task, closeCode, reason) {
        actualSession = session;
        actualTask = task;
        actualCloseCode = closeCode!;
        actualReason = utf8.decode(reason!.bytes);
        c.complete();
      });

      final request = MutableURLRequest.fromUrl(
          Uri.parse('http://localhost:${server.port}'));

      final task = session.webSocketTaskWithRequest(request)..resume();

      expect(
          task.receiveMessage(),
          throwsA(isA<Error>()
              .having((e) => e.code, 'code', 57 // Socket is not connected.
                  )));
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualCloseCode, 1005);
      expect(actualReason, '');
    });

    test('close code', () async {
      final c = Completer<void>();
      late int actualCloseCode;
      late String? actualReason;
      late URLSession actualSession;
      late URLSessionWebSocketTask actualTask;

      serverCode = 4000;
      serverReason = null;

      final session = URLSession.sessionWithConfiguration(config,
          onWebSocketTaskOpened: (session, task, protocol) {},
          onWebSocketTaskClosed: (session, task, closeCode, reason) {
        actualSession = session;
        actualTask = task;
        actualCloseCode = closeCode!;
        actualReason = utf8.decode(reason!.bytes);
        c.complete();
      });

      final request = MutableURLRequest.fromUrl(
          Uri.parse('http://localhost:${server.port}'));

      final task = session.webSocketTaskWithRequest(request)..resume();

      expect(
          task.receiveMessage(),
          throwsA(isA<Error>()
              .having((e) => e.code, 'code', 57 // Socket is not connected.
                  )));
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualCloseCode, serverCode);
      expect(actualReason, '');
    });

    test('close code and reason', () async {
      final c = Completer<void>();
      late int actualCloseCode;
      late String? actualReason;
      late URLSession actualSession;
      late URLSessionWebSocketTask actualTask;

      serverCode = 4000;
      serverReason = 'no real reason';

      final session = URLSession.sessionWithConfiguration(config,
          onWebSocketTaskOpened: (session, task, protocol) {},
          onWebSocketTaskClosed: (session, task, closeCode, reason) {
        actualSession = session;
        actualTask = task;
        actualCloseCode = closeCode!;
        actualReason = utf8.decode(reason!.bytes);
        c.complete();
      });

      final request = MutableURLRequest.fromUrl(
          Uri.parse('http://localhost:${server.port}'));

      final task = session.webSocketTaskWithRequest(request)..resume();

      expect(
          task.receiveMessage(),
          throwsA(isA<Error>()
              .having((e) => e.code, 'code', 57 // Socket is not connected.
                  )));
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualCloseCode, serverCode);
      expect(actualReason, serverReason);
    });
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('backgroundSession', () {
    final config =
        URLSessionConfiguration.backgroundSession('backgroundSession');
    testOnComplete(config);
    testOnResponse(config);
    testOnData(config);
    // onRedirect is not called for background sessions.
    testOnFinishedDownloading(config);
    // WebSocket tasks are not supported in background sessions.
  });

  group('defaultSessionConfiguration', () {
    final config = URLSessionConfiguration.defaultSessionConfiguration();
    testOnComplete(config);
    testOnResponse(config);
    testOnData(config);
    testOnRedirect(config);
    testOnFinishedDownloading(config);
    testOnWebSocketTaskOpened(config);
    testOnWebSocketTaskClosed(config);
  });

  group('ephemeralSessionConfiguration', () {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration();
    testOnComplete(config);
    testOnResponse(config);
    testOnData(config);
    testOnRedirect(config);
    testOnFinishedDownloading(config);
    testOnWebSocketTaskOpened(config);
    testOnWebSocketTaskClosed(config);
  });
}
