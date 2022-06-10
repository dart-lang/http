// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:cupertinohttp/cupertinohttp.dart';

testDataTaskWithCompletionHandler(URLSession session) {
  group('dataTaskWithCompletionHandler', () {
    late HttpServer successServer;
    late HttpServer failureServer;
    late HttpServer redirectServer;

    setUp(() async {
      successServer = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          request.drain();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write("Hello World");
          await request.response.close();
        });
      failureServer = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          request.drain();
          request.response.statusCode = 500;
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.write("Hello World");
          await request.response.close();
        });
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
      successServer.close();
      failureServer.close();
      redirectServer.close();
    });

    test('success', () async {
      final c = Completer<void>();
      Data? data;
      HTTPURLResponse? response;
      Error? error;

      final task = session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${successServer.port}')), (d, r, e) {
        data = d;
        response = r;
        error = e;
        c.complete();
      });

      task.resume();
      await c.future;

      expect(data!.bytes, "Hello World".codeUnits);
      expect(response!.statusCode, 200);
      expect(error, null);
    });

    test('success no data', () async {
      final c = Completer<void>();
      Data? data;
      HTTPURLResponse? response;
      Error? error;

      final request = MutableURLRequest.fromUrl(
          Uri.parse('http://localhost:${successServer.port}'));
      request.httpMethod = 'HEAD';

      final task = session.dataTaskWithCompletionHandler(request, (d, r, e) {
        data = d;
        response = r;
        error = e;
        c.complete();
      });
      task.resume();
      await c.future;

      expect(data, null);
      expect(response!.statusCode, 200);
      expect(error, null);
    });

    test('500 response', () async {
      final c = Completer<void>();
      Data? data;
      HTTPURLResponse? response;
      Error? error;

      final task = session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${failureServer.port}')), (d, r, e) {
        data = d;
        response = r;
        error = e;
        c.complete();
      });

      task.resume();
      await c.future;

      expect(data!.bytes, "Hello World".codeUnits);
      expect(response!.statusCode, 500);
      expect(error, null);
    });

    test('too many redirects', () async {
      // Ensures that the delegate used to implement the completion handler
      // does not interfere with the default redirect behavior.
      final c = Completer<void>();
      Data? data;
      HTTPURLResponse? response;
      Error? error;

      final task = session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(
              Uri.parse('http://localhost:${redirectServer.port}/100')),
          (d, r, e) {
        data = d;
        response = r;
        error = e;
        c.complete();
      });

      task.resume();
      await c.future;

      expect(response, null);
      expect(data, null);
      expect(error!.code, -1007); // kCFURLErrorHTTPTooManyRedirects
    });

    test('unable to connect', () async {
      final c = Completer<void>();
      Data? data;
      HTTPURLResponse? response;
      Error? error;

      final task = session.dataTaskWithCompletionHandler(
          URLRequest.fromUrl(Uri.parse('http://this is not a valid URL')),
          (d, r, e) {
        data = d;
        response = r;
        error = e;
        c.complete();
      });

      task.resume();
      await c.future;
      expect(data, null);
      expect(response, null);
      expect(error!.code, -1003); // kCFURLErrorCannotFindHost
      expect(error!.localizedRecoverySuggestion, null);
    });
  });
}

testURLSession(URLSession session) {
  group('URLSession', () {
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

    test('dataTask', () async {
      final task = session.dataTaskWithRequest(
          URLRequest.fromUrl(Uri.parse('http://localhost:${server.port}')));

      task.resume();
      while (task.state != URLSessionTaskState.urlSessionTaskStateCompleted) {
        // Let the event loop run.
        await Future.delayed(const Duration());
      }
      final response = task.response as HTTPURLResponse;
      expect(response.statusCode, 200);
    });

    testDataTaskWithCompletionHandler(session);
  });
}

void main() {
  group('sharedSession', () {
    final session = URLSession.sharedSession();

    test('configration', () {
      expect(session.configuration, isA<URLSessionConfiguration>());
    });

    testURLSession(session);
  });

  group('defaultSessionConfiguration', () {
    final config = URLSessionConfiguration.defaultSessionConfiguration()
      ..allowsCellularAccess = false;
    final session = URLSession.sessionWithConfiguration(config);

    test('configration', () {
      expect(session.configuration.allowsCellularAccess, false);
    });

    testURLSession(session);
  });
}
