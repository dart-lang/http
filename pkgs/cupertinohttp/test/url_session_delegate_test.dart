import 'dart:async';
import 'dart:io';

import 'package:cupertinohttp/cupertinohttp.dart';
import 'package:cupertinohttp/src/native_cupertino_bindings.dart';
import 'package:test/test.dart';

void testOnComplete() {
  group('onComplete', () {
    late HttpServer server;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          request.drain();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write("Hello World");
          await request.response.close();
        });
    });
    tearDown(() {
      server.close();
    });

    test('success', () async {
      final c = Completer();
      Error? actualError;
      late URLSession actualSession;
      late URLSessionTask actualTask;

      late URLSession session = URLSession.sessionWithConfiguration(
          URLSessionConfiguration.defaultSessionConfiguration(),
          onComplete: (s, t, e) {
        actualSession = s;
        actualTask = t;
        actualError = e;
        c.complete();
      });

      final task = session.dataTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')));

      task.resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualError, null);
    });

    test('bad host', () async {
      final c = Completer();
      Error? actualError;
      late URLSession actualSession;
      late URLSessionTask actualTask;

      late URLSession session = URLSession.sessionWithConfiguration(
          URLSessionConfiguration.defaultSessionConfiguration(),
          onComplete: (s, t, e) {
        actualSession = s;
        actualTask = t;
        actualError = e;
        c.complete();
      });

      final task = session.dataTaskWithRequest(
          URLRequest.fromUrl(Uri.https('does-not-exist', '')));

      task.resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualError!.code, -1003); // kCFURLErrorCannotFindHost
    });
  });
}

void testOnResponse() {
  group('onResponse', () {
    late HttpServer server;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          request.drain();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write("Hello World");
          await request.response.close();
        });
    });
    tearDown(() {
      server.close();
    });

    test('success', () async {
      final c = Completer();
      late HTTPURLResponse actualResponse;
      late URLSession actualSession;
      late URLSessionTask actualTask;

      late URLSession session = URLSession.sessionWithConfiguration(
          URLSessionConfiguration.defaultSessionConfiguration(),
          onResponse: (s, t, r) {
        actualSession = s;
        actualTask = t;
        actualResponse = r as HTTPURLResponse;
        c.complete();
        return URLSessionResponseDisposition.urlSessionResponseAllow;
      });

      final task = session.dataTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')));

      task.resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualResponse.statusCode, 200);
    });

    test('bad host', () async {
      // `onResponse` should not be called because there was no valid response.
      final c = Completer();
      var called = false;

      late URLSession session = URLSession.sessionWithConfiguration(
          URLSessionConfiguration.defaultSessionConfiguration(),
          onComplete: (session, task, error) => c.complete(),
          onResponse: (s, t, r) {
            called = true;
            return URLSessionResponseDisposition.urlSessionResponseAllow;
          });

      final task = session.dataTaskWithRequest(
          URLRequest.fromUrl(Uri.https('does-not-exist', '')));

      task.resume();
      await c.future;
      expect(called, false);
    });
  });
}

void testOnData() {
  group('onData', () {
    late HttpServer server;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          request.drain();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write("Hello World");
          await request.response.close();
        });
    });
    tearDown(() {
      server.close();
    });

    test('success', () async {
      final c = Completer();
      final actualData = MutableData.empty();
      late URLSession actualSession;
      late URLSessionTask actualTask;

      late URLSession session = URLSession.sessionWithConfiguration(
          URLSessionConfiguration.defaultSessionConfiguration(),
          onComplete: (s, t, r) => c.complete(),
          onData: (s, t, d) {
            actualSession = s;
            actualTask = t;
            actualData.appendBytes(d.bytes);
          });

      final task = session.dataTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')));

      task.resume();
      await c.future;
      expect(actualSession, session);
      expect(actualTask, task);
      expect(actualData.bytes, "Hello World".codeUnits);
    });
  });
}

void testOnRedirect() {
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
            String nextPath = n - 1 == 0 ? '' : '${n - 1}';
            unawaited(request.response.redirect(Uri.parse(
                'http://localhost:${redirectServer.port}/$nextPath')));
          }
        });
    });
    tearDown(() {
      redirectServer.close();
    });

    test('disallow redirect', () async {
      final config = URLSessionConfiguration.defaultSessionConfiguration();
      final session = URLSession.sessionWithConfiguration(
        config,
        onRedirect:
            (redirectSession, redirectTask, redirectResponse, newRequest) {
          return null;
        },
      );
      final c = Completer<void>();
      HTTPURLResponse? response;
      Error? error;

      final task = session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${redirectServer.port}/100')),
          (d, r, e) {
        response = r;
        error = e;
        c.complete();
      });

      task.resume();
      await c.future;

      expect(response!.statusCode, 302);
      expect(response!.allHeaderFields['Location'],
          'http://localhost:${redirectServer.port}/99');
      expect(error, null);
    });

    test('use preposed redirect request', () async {
      final config = URLSessionConfiguration.defaultSessionConfiguration();
      final session = URLSession.sessionWithConfiguration(
        config,
        onRedirect:
            (redirectSession, redirectTask, redirectResponse, newRequest) {
          return newRequest;
        },
      );
      final c = Completer<void>();
      HTTPURLResponse? response;
      Error? error;

      final task = session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${redirectServer.port}/1')),
          (d, r, e) {
        response = r;
        error = e;
        c.complete();
      });

      task.resume();
      await c.future;

      expect(response!.statusCode, 200);
      expect(error, null);
    });

    test('use custom redirect request', () async {
      final config = URLSessionConfiguration.defaultSessionConfiguration();
      final session = URLSession.sessionWithConfiguration(
        config,
        onRedirect:
            (redirectSession, redirectTask, redirectResponse, newRequest) {
          return URLRequest.fromUrl(
              Uri.parse("http://localhost:${redirectServer.port}/"));
        },
      );
      final c = Completer<void>();
      HTTPURLResponse? response;
      Error? error;

      final task = session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${redirectServer.port}/100')),
          (d, r, e) {
        response = r;
        error = e;
        c.complete();
      });

      task.resume();
      await c.future;

      expect(response!.statusCode, 200);
      expect(error, null);
    });

    test('exception in http redirection', () async {
      final config = URLSessionConfiguration.defaultSessionConfiguration();
      final session = URLSession.sessionWithConfiguration(
        config,
        onRedirect:
            (redirectSession, redirectTask, redirectResponse, newRequest) {
          throw UnimplementedError();
        },
      );
      final c = Completer<void>();
      HTTPURLResponse? response;
      Error? error;

      final task = session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${redirectServer.port}/100')),
          (d, r, e) {
        response = r;
        error = e;
        c.complete();
      });

      task.resume();
      await c.future;

      expect(response!.statusCode, 302);
      // TODO(https://github.com/dart-lang/ffigen/issues/386): Check that the
      // error is set.
    }, skip: "Error not set for redirect exceptions.");

    test('3 redirects', () async {
      final config = URLSessionConfiguration.defaultSessionConfiguration();
      int redirectCounter = 0;
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

      final task = session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${redirectServer.port}/3')),
          (d, r, e) {
        response = r;
        error = e;
        c.complete();
      });

      task.resume();
      await c.future;

      expect(response!.statusCode, 200);
      expect(error, null);
    });

    test('allow too many redirects', () async {
      // The Foundation URL Loading System limits the number of redirects
      // even when a redirect delegate is present and allows the redirect.
      final config = URLSessionConfiguration.defaultSessionConfiguration();
      final session = URLSession.sessionWithConfiguration(
        config,
        onRedirect:
            (redirectSession, redirectTask, redirectResponse, newRequest) {
          return newRequest;
        },
      );
      final c = Completer<void>();
      HTTPURLResponse? response;
      Error? error;

      final task = session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${redirectServer.port}/100')),
          (d, r, e) {
        response = r;
        error = e;
        c.complete();
      });

      task.resume();
      await c.future;

      expect(response, null);
      expect(error!.code, -1007); // kCFURLErrorHTTPTooManyRedirects
    });
  });
}

void main() {
  testOnComplete();
  testOnResponse();
  testOnData();
  testOnRedirect();
}
