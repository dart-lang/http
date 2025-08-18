// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:objective_c/objective_c.dart';
import 'package:test/test.dart';

void testOnComplete(URLSessionConfiguration Function() config) {
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
      NSError? actualError;
      late URLSession actualSession;
      late URLSessionTask actualTask;

      final session = URLSession.sessionWithConfiguration(
        config(),
        onComplete: (s, t, e) {
          actualSession = s;
          actualTask = t;
          actualError = e;
          c.complete();
        },
      );

      final task = session.dataTaskWithRequest(
        URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')),
      )..resume();
      await c.future;

      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualError, null);
      session.finishTasksAndInvalidate();
    });

    test('bad host', () async {
      final c = Completer<void>();
      NSError? actualError;
      late URLSession actualSession;
      late URLSessionTask actualTask;

      final session = URLSession.sessionWithConfiguration(
        config(),
        onComplete: (s, t, e) {
          actualSession = s;
          actualTask = t;
          actualError = e;
          c.complete();
        },
      );

      final task = session.dataTaskWithRequest(
        URLRequest.fromUrl(Uri.https('does-not-exist', '')),
      )..resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(
        actualError!.code,
        anyOf(
          -1001, // kCFURLErrorTimedOut
          -1003, // kCFURLErrorCannotFindHost
        ),
      );
      session.finishTasksAndInvalidate();
    });
  });
}

void testOnResponse(URLSessionConfiguration Function() config) {
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

      final session = URLSession.sessionWithConfiguration(
        config(),
        onResponse: (s, t, r) {
          actualSession = s;
          actualTask = t;
          actualResponse = r as HTTPURLResponse;
          c.complete();
          return NSURLSessionResponseDisposition.NSURLSessionResponseAllow;
        },
      );

      final task = session.dataTaskWithRequest(
        URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')),
      )..resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualResponse.statusCode, 200);
      session.finishTasksAndInvalidate();
    });

    test('bad host', () async {
      // `onResponse` should not be called because there was no valid response.
      final c = Completer<void>();
      var called = false;

      final session = URLSession.sessionWithConfiguration(
        config(),
        onComplete: (session, task, error) => c.complete(),
        onResponse: (s, t, r) {
          called = true;
          return NSURLSessionResponseDisposition.NSURLSessionResponseAllow;
        },
      );

      session
          .dataTaskWithRequest(
            URLRequest.fromUrl(Uri.https('does-not-exist', '')),
          )
          .resume();
      await c.future;
      expect(called, false);
      session.finishTasksAndInvalidate();
    });
  });
}

void testOnData(URLSessionConfiguration Function() config) {
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
      final actualData = NSMutableData.data();
      late URLSession actualSession;
      late URLSessionTask actualTask;

      final session = URLSession.sessionWithConfiguration(
        config(),
        onComplete: (s, t, r) => c.complete(),
        onData: (s, t, d) {
          actualSession = s;
          actualTask = t;
          actualData.appendData(d);
        },
      );

      final task = session.dataTaskWithRequest(
        URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')),
      )..resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualData.toList(), 'Hello World'.codeUnits);
      session.finishTasksAndInvalidate();
    });
  });
}

void testOnFinishedDownloading(URLSessionConfiguration Function() config) {
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

      final session = URLSession.sessionWithConfiguration(
        config(),
        onComplete: (s, t, r) => c.complete(),
        onFinishedDownloading: (s, t, uri) {
          actualSession = s;
          actualTask = t;
          actualContent = File.fromUri(uri).readAsStringSync();
        },
      );

      final task = session.downloadTaskWithRequest(
        URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')),
      )..resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualContent, 'Hello World');
      session.finishTasksAndInvalidate();
    });
  });
}

void testOnRedirect(URLSessionConfiguration Function() config) {
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
            unawaited(
              request.response.redirect(
                Uri.parse('http://localhost:${redirectServer.port}/$nextPath'),
              ),
            );
          }
        });
    });
    tearDown(() {
      redirectServer.close();
    });

    test('disallow redirect', () async {
      final session = URLSession.sessionWithConfiguration(
        config(),
        onRedirect:
            (redirectSession, redirectTask, redirectResponse, newRequest) =>
                null,
      );
      final c = Completer<void>();
      URLResponse? response;
      NSError? error;

      session.dataTaskWithCompletionHandler(
        URLRequest.fromUrl(
          Uri.parse('http://localhost:${redirectServer.port}/100'),
        ),
        (d, r, e) {
          response = r;
          error = e;
          c.complete();
        },
      ).resume();
      await c.future;

      expect(
        response,
        isA<HTTPURLResponse>()
            .having((r) => r.statusCode, 'statusCode', 302)
            .having(
              (r) => r.allHeaderFields['Location'],
              "allHeaderFields['Location']",
              'http://localhost:${redirectServer.port}/99',
            ),
      );
      expect(error, null);
      session.finishTasksAndInvalidate();
    });

    test('use proposed redirect request', () async {
      final session = URLSession.sessionWithConfiguration(
        config(),
        onRedirect:
            (redirectSession, redirectTask, redirectResponse, newRequest) =>
                newRequest,
      );
      final c = Completer<void>();
      URLResponse? response;
      NSError? error;

      session.dataTaskWithCompletionHandler(
        URLRequest.fromUrl(
          Uri.parse('http://localhost:${redirectServer.port}/1'),
        ),
        (d, r, e) {
          response = r;
          error = e;
          c.complete();
        },
      ).resume();
      await c.future;

      expect(
        response,
        isA<HTTPURLResponse>().having((r) => r.statusCode, 'statusCode', 200),
      );
      expect(error, null);
      session.finishTasksAndInvalidate();
    });

    test('use custom redirect request', () async {
      final session = URLSession.sessionWithConfiguration(
        config(),
        onRedirect:
            (redirectSession, redirectTask, redirectResponse, newRequest) =>
                URLRequest.fromUrl(
                  Uri.parse('http://localhost:${redirectServer.port}/'),
                ),
      );
      final c = Completer<void>();
      URLResponse? response;
      NSError? error;

      session.dataTaskWithCompletionHandler(
        URLRequest.fromUrl(
          Uri.parse('http://localhost:${redirectServer.port}/100'),
        ),
        (d, r, e) {
          response = r;
          error = e;
          c.complete();
        },
      ).resume();
      await c.future;

      expect(
        response,
        isA<HTTPURLResponse>().having((r) => r.statusCode, 'statusCode', 200),
      );
      expect(error, null);
      session.finishTasksAndInvalidate();
    });

    test(
      'exception in http redirection',
      () async {
        final session = URLSession.sessionWithConfiguration(
          config(),
          onRedirect:
              (redirectSession, redirectTask, redirectResponse, newRequest) {
                throw UnimplementedError();
              },
        );
        final c = Completer<void>();
        URLResponse? response;
        // ignore: unused_local_variable
        NSError? error;

        session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
            Uri.parse('http://localhost:${redirectServer.port}/100'),
          ),
          (d, r, e) {
            response = r;
            error = e;
            c.complete();
          },
        ).resume();
        await c.future;

        expect(
          response,
          isA<HTTPURLResponse>().having((r) => r.statusCode, 'statusCode', 302),
        );
        // TODO(https://github.com/dart-lang/ffigen/issues/386): Check that the
        // error is set.
        session.finishTasksAndInvalidate();
      },
      skip: 'Error not set for redirect exceptions.',
    );

    test('3 redirects', () async {
      var redirectCounter = 0;
      final session = URLSession.sessionWithConfiguration(
        config(),
        onRedirect:
            (redirectSession, redirectTask, redirectResponse, newRequest) {
              ++redirectCounter;
              return newRequest;
            },
      );
      final c = Completer<void>();
      URLResponse? response;
      NSError? error;

      session.dataTaskWithCompletionHandler(
        URLRequest.fromUrl(
          Uri.parse('http://localhost:${redirectServer.port}/3'),
        ),
        (d, r, e) {
          response = r;
          error = e;
          c.complete();
        },
      ).resume();
      await c.future;

      expect(redirectCounter, 3);
      expect(
        response,
        isA<HTTPURLResponse>().having((r) => r.statusCode, 'statusCode', 200),
      );
      expect(error, null);
      session.finishTasksAndInvalidate();
    });

    test('allow too many redirects', () async {
      // The Foundation URL Loading System limits the number of redirects
      // even when a redirect delegate is present and allows the redirect.
      final session = URLSession.sessionWithConfiguration(
        config(),
        onRedirect:
            (redirectSession, redirectTask, redirectResponse, newRequest) =>
                newRequest,
      );
      final c = Completer<void>();
      URLResponse? response;
      NSError? error;

      session.dataTaskWithCompletionHandler(
        URLRequest.fromUrl(
          Uri.parse('http://localhost:${redirectServer.port}/100'),
        ),
        (d, r, e) {
          response = r;
          error = e;
          c.complete();
        },
      ).resume();
      await c.future;

      expect(
        response,
        anyOf(
          isNull,
          isA<HTTPURLResponse>()
              .having((r) => r.statusCode, 'statusCode', 302)
              .having(
                (r) => r.allHeaderFields['Location'],
                "r.allHeaderFields['Location']",
                matches(
                  'http://localhost:${redirectServer.port}/'
                  r'\d+',
                ),
              ),
        ),
      );
      expect(error!.code, -1007); // kCFURLErrorHTTPTooManyRedirects
      session.finishTasksAndInvalidate();
    });
  });
}

void testOnWebSocketTaskOpened(URLSessionConfiguration Function() config) {
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

      final session = URLSession.sessionWithConfiguration(
        config(),
        onWebSocketTaskOpened: (s, t, p) {
          actualSession = s;
          actualTask = t;
          actualProtocol = p;
          c.complete();
        },
      );

      final request = MutableURLRequest.fromUrl(
        Uri.parse('http://localhost:${server.port}'),
      )..setValueForHttpHeaderField('Sec-WebSocket-Protocol', 'myprotocol');

      final task = session.webSocketTaskWithRequest(request)..resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualProtocol, 'myprotocol');
      session.finishTasksAndInvalidate();
    });

    test('without protocol', () async {
      final c = Completer<void>();
      late String? actualProtocol;
      late URLSession actualSession;
      late URLSessionWebSocketTask actualTask;

      final session = URLSession.sessionWithConfiguration(
        config(),
        onWebSocketTaskOpened: (s, t, p) {
          actualSession = s;
          actualTask = t;
          actualProtocol = p;
          c.complete();
        },
      );

      final request = MutableURLRequest.fromUrl(
        Uri.parse('http://localhost:${server.port}'),
      );
      final task = session.webSocketTaskWithRequest(request)..resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualProtocol, null);
      session.finishTasksAndInvalidate();
    });

    test('server failure', () async {
      final c = Completer<void>();
      var onWebSocketTaskOpenedCalled = false;
      NSError? actualError;

      final session = URLSession.sessionWithConfiguration(
        config(),
        onWebSocketTaskOpened: (s, t, p) {
          onWebSocketTaskOpenedCalled = true;
        },
        onComplete: (s, t, e) {
          actualError = e;
          c.complete();
        },
      );

      final request = MutableURLRequest.fromUrl(
        Uri.parse('http://localhost:${server.port}?error=1'),
      );
      session.webSocketTaskWithRequest(request).resume();
      await c.future;
      expect(actualError, isNotNull);
      expect(onWebSocketTaskOpenedCalled, false);
      session.finishTasksAndInvalidate();
    });
  });
}

void testOnWebSocketTaskClosed(URLSessionConfiguration Function() config) {
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
          final webSocket = await WebSocketTransformer.upgrade(request);
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

      final session = URLSession.sessionWithConfiguration(
        config(),
        onWebSocketTaskOpened: (session, task, protocol) {},
        onWebSocketTaskClosed: (session, task, closeCode, reason) {
          actualSession = session;
          actualTask = task;
          actualCloseCode = closeCode!;
          actualReason = utf8.decode(reason!.toList());
          c.complete();
        },
      );

      final request = MutableURLRequest.fromUrl(
        Uri.parse('http://localhost:${server.port}'),
      );

      final task = session.webSocketTaskWithRequest(request)..resume();

      expect(
        task.receiveMessage(),
        throwsA(
          isA<NSError>().having(
            (e) => e.code,
            'code',
            57, // Socket is not connected.
          ),
        ),
      );
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualCloseCode, 1005);
      expect(actualReason, '');
      session.finishTasksAndInvalidate();
    });

    test('close code', () async {
      final c = Completer<void>();
      late int actualCloseCode;
      late String? actualReason;
      late URLSession actualSession;
      late URLSessionWebSocketTask actualTask;

      serverCode = 4000;
      serverReason = null;

      final session = URLSession.sessionWithConfiguration(
        config(),
        onWebSocketTaskOpened: (session, task, protocol) {},
        onWebSocketTaskClosed: (session, task, closeCode, reason) {
          actualSession = session;
          actualTask = task;
          actualCloseCode = closeCode!;
          actualReason = utf8.decode(reason!.toList());
          c.complete();
        },
      );

      final request = MutableURLRequest.fromUrl(
        Uri.parse('http://localhost:${server.port}'),
      );

      final task = session.webSocketTaskWithRequest(request)..resume();

      expect(
        task.receiveMessage(),
        throwsA(
          isA<NSError>().having(
            (e) => e.code,
            'code',
            57, // Socket is not connected.
          ),
        ),
      );
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualCloseCode, serverCode);
      expect(actualReason, '');
      session.finishTasksAndInvalidate();
    });

    test('close code and reason', () async {
      final c = Completer<void>();
      late int actualCloseCode;
      late String? actualReason;
      late URLSession actualSession;
      late URLSessionWebSocketTask actualTask;

      serverCode = 4000;
      serverReason = 'no real reason';

      final session = URLSession.sessionWithConfiguration(
        config(),
        onWebSocketTaskOpened: (session, task, protocol) {},
        onWebSocketTaskClosed: (session, task, closeCode, reason) {
          actualSession = session;
          actualTask = task;
          actualCloseCode = closeCode!;
          actualReason = utf8.decode(reason!.toList());
          c.complete();
        },
      );

      final request = MutableURLRequest.fromUrl(
        Uri.parse('http://localhost:${server.port}'),
      );

      final task = session.webSocketTaskWithRequest(request)..resume();

      expect(
        task.receiveMessage(),
        throwsA(
          isA<NSError>().having(
            (e) => e.code,
            'code',
            57, // Socket is not connected.
          ),
        ),
      );
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualCloseCode, serverCode);
      expect(actualReason, serverReason);
      session.finishTasksAndInvalidate();
    });
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('backgroundSession', () {
    var count = 0;
    URLSessionConfiguration config() {
      ++count;
      return URLSessionConfiguration.backgroundSession(
        'backgroundSession{$count}',
      );
    }

    testOnComplete(config);
    // onResponse is not called for background sessions.
    testOnData(config);
    // onRedirect is not called for background sessions.
    testOnFinishedDownloading(config);
    // WebSocket tasks are not supported in background sessions.
  });

  group('defaultSessionConfiguration', () {
    URLSessionConfiguration config() =>
        URLSessionConfiguration.defaultSessionConfiguration();
    testOnComplete(config);
    testOnResponse(config);
    testOnData(config);
    testOnRedirect(config);
    testOnFinishedDownloading(config);
    testOnWebSocketTaskOpened(config);
    testOnWebSocketTaskClosed(config);
  });

  group('ephemeralSessionConfiguration', () {
    URLSessionConfiguration config() =>
        URLSessionConfiguration.ephemeralSessionConfiguration();
    testOnComplete(config);
    testOnResponse(config);
    testOnData(config);
    testOnRedirect(config);
    testOnFinishedDownloading(config);
    testOnWebSocketTaskOpened(config);
    testOnWebSocketTaskClosed(config);
  });
}
