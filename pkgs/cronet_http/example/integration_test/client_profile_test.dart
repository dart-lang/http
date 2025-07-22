// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cronet_http/src/cronet_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http_profile/http_profile.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('profile', () {
    final profilingEnabled = HttpClientRequestProfile.profilingEnabled;

    setUpAll(() {
      HttpClientRequestProfile.profilingEnabled = true;
    });

    tearDownAll(() {
      HttpClientRequestProfile.profilingEnabled = profilingEnabled;
    });

    group('POST', () {
      late HttpServer successServer;
      late Uri successServerUri;
      late HttpClientRequestProfile profile;

      setUpAll(() async {
        successServer = (await HttpServer.bind('localhost', 0))
          ..listen((request) async {
            await request.drain<void>();
            request.response.headers.set('Content-Type', 'text/plain');
            request.response.headers.set('Content-Length', '11');
            request.response.write('Hello World');
            await request.response.close();
          });
        successServerUri = Uri.http('localhost:${successServer.port}');
        final client = CronetClientWithProfile.defaultCronetEngine();
        await client.post(successServerUri,
            headers: {'Content-Type': 'text/plain'}, body: 'Hi');
        profile = client.profile!;
      });
      tearDownAll(() {
        successServer.close();
      });

      test('profile attributes', () {
        expect(profile.events, isEmpty);
        expect(profile.requestMethod, 'POST');
        expect(profile.requestUri, successServerUri.toString());
        expect(profile.connectionInfo,
            containsPair('package', 'package:cronet_http'));
      });

      test('request attributes', () {
        expect(profile.requestData.bodyBytes, 'Hi'.codeUnits);
        expect(profile.requestData.contentLength, 2);
        expect(profile.requestData.endTime, isNotNull);
        expect(profile.requestData.error, isNull);
        expect(
            profile.requestData.headers, containsPair('Content-Length', ['2']));
        expect(profile.requestData.headers,
            containsPair('Content-Type', ['text/plain; charset=utf-8']));
        expect(profile.requestData.persistentConnection, isNull);
        expect(profile.requestData.proxyDetails, isNull);
        expect(profile.requestData.startTime, isNotNull);
      });

      test('response attributes', () {
        expect(profile.responseData.bodyBytes, 'Hello World'.codeUnits);
        expect(profile.responseData.compressionState, isNull);
        expect(profile.responseData.contentLength, 11);
        expect(profile.responseData.endTime, isNotNull);
        expect(profile.responseData.error, isNull);
        expect(profile.responseData.headers,
            containsPair('content-type', ['text/plain']));
        expect(profile.responseData.headers,
            containsPair('content-length', ['11']));
        expect(profile.responseData.isRedirect, false);
        expect(profile.responseData.persistentConnection, isNull);
        expect(profile.responseData.reasonPhrase, 'OK');
        expect(profile.responseData.redirects, isEmpty);
        expect(profile.responseData.startTime, isNotNull);
        expect(profile.responseData.statusCode, 200);
      });
    });

    group('failed POST request', () {
      late HttpClientRequestProfile profile;

      setUpAll(() async {
        final client = CronetClientWithProfile.defaultCronetEngine();
        try {
          await client.post(Uri.http('thisisnotahost'),
              headers: {'Content-Type': 'text/plain'}, body: 'Hi');
          fail('expected exception');
        } on ClientException {
          // Expected exception.
        }
        profile = client.profile!;
      });

      test('profile attributes', () {
        expect(profile.events, isEmpty);
        expect(profile.requestMethod, 'POST');
        expect(profile.requestUri, 'http://thisisnotahost');
        expect(profile.connectionInfo,
            containsPair('package', 'package:cronet_http'));
      });

      test('request attributes', () {
        expect(profile.requestData.bodyBytes, 'Hi'.codeUnits);
        expect(profile.requestData.contentLength, 2);
        expect(profile.requestData.endTime, isNotNull);
        expect(profile.requestData.error, startsWith('ClientException:'));
        expect(
            profile.requestData.headers, containsPair('Content-Length', ['2']));
        expect(profile.requestData.headers,
            containsPair('Content-Type', ['text/plain; charset=utf-8']));
        expect(profile.requestData.persistentConnection, isNull);
        expect(profile.requestData.proxyDetails, isNull);
        expect(profile.requestData.startTime, isNotNull);
      });

      test('response attributes', () {
        expect(profile.responseData.bodyBytes, isEmpty);
        expect(profile.responseData.compressionState, isNull);
        expect(profile.responseData.contentLength, isNull);
        expect(profile.responseData.endTime, isNull);
        expect(profile.responseData.error, isNull);
        expect(profile.responseData.headers, isNull);
        expect(profile.responseData.isRedirect, isNull);
        expect(profile.responseData.persistentConnection, isNull);
        expect(profile.responseData.reasonPhrase, isNull);
        expect(profile.responseData.redirects, isEmpty);
        expect(profile.responseData.startTime, isNull);
        expect(profile.responseData.statusCode, isNull);
      });
    });

    group('failed POST response', () {
      late HttpServer successServer;
      late Uri successServerUri;
      late HttpClientRequestProfile profile;

      setUpAll(() async {
        successServer = (await HttpServer.bind('localhost', 0))
          ..listen((request) async {
            await request.drain<void>();
            request.response.headers.set('Content-Type', 'text/plain');
            request.response.headers.set('Content-Length', '11');
            final socket = await request.response.detachSocket();
            await socket.close();
          });
        successServerUri = Uri.http('localhost:${successServer.port}');
        final client = CronetClientWithProfile.defaultCronetEngine();

        try {
          await client.post(successServerUri,
              headers: {'Content-Type': 'text/plain'}, body: 'Hi');
          fail('expected exception');
        } on ClientException {
          // Expected exception.
        }
        profile = client.profile!;
      });
      tearDownAll(() {
        successServer.close();
      });

      test('profile attributes', () {
        expect(profile.events, isEmpty);
        expect(profile.requestMethod, 'POST');
        expect(profile.requestUri, successServerUri.toString());
        expect(profile.connectionInfo,
            containsPair('package', 'package:cronet_http'));
      });

      test('request attributes', () {
        expect(profile.requestData.bodyBytes, 'Hi'.codeUnits);
        expect(profile.requestData.contentLength, 2);
        expect(profile.requestData.endTime, isNotNull);
        expect(profile.requestData.error, isNull);
        expect(
            profile.requestData.headers, containsPair('Content-Length', ['2']));
        expect(profile.requestData.headers,
            containsPair('Content-Type', ['text/plain; charset=utf-8']));
        expect(profile.requestData.persistentConnection, isNull);
        expect(profile.requestData.proxyDetails, isNull);
        expect(profile.requestData.startTime, isNotNull);
      });

      test('response attributes', () {
        expect(profile.responseData.bodyBytes, isEmpty);
        expect(profile.responseData.compressionState, isNull);
        expect(profile.responseData.contentLength, 11);
        expect(profile.responseData.endTime, isNotNull);
        expect(profile.responseData.error, startsWith('ClientException:'));
        expect(profile.responseData.headers,
            containsPair('content-type', ['text/plain']));
        expect(profile.responseData.headers,
            containsPair('content-length', ['11']));
        expect(profile.responseData.isRedirect, false);
        expect(profile.responseData.persistentConnection, isNull);
        expect(profile.responseData.reasonPhrase, 'OK');
        expect(profile.responseData.redirects, isEmpty);
        expect(profile.responseData.startTime, isNotNull);
        expect(profile.responseData.statusCode, 200);
      });
    });

    group('cancel streaming GET response', () {
      late HttpServer successServer;
      late Uri successServerUri;
      late HttpClientRequestProfile profile;
      late List<int> receivedData;

      setUpAll(() async {
        final cancelCompleter = Completer<void>();
        successServer = (await HttpServer.bind('localhost', 0))
          ..listen((request) async {
            await request.drain<void>();
            request.response.headers.set('Content-Type', 'text/plain');
            while (!cancelCompleter.isCompleted) {
              request.response.write('Hello World');
              await request.response.flush();
              // Let the event loop run.
              await Future(() {});
            }
            await request.response.close();
          });
        successServerUri = Uri.http('localhost:${successServer.port}');
        final client = CronetClientWithProfile.defaultCronetEngine();
        final request = StreamedRequest('GET', successServerUri);
        unawaited(request.sink.close());
        final response = await client.send(request);
        var i = 0;
        late final StreamSubscription<List<int>> s;
        receivedData = [];
        s = response.stream.listen((d) {
          receivedData += d;
          if (++i == 2) {
            s.cancel();
            cancelCompleter.complete();
          }
        });
        await cancelCompleter.future;
        profile = client.profile!;
      });
      tearDownAll(() {
        successServer.close();
      });

      test('request attributes', () async {
        expect(profile.requestData.contentLength, isNull);
        expect(profile.requestData.startTime, isNotNull);
        expect(profile.requestData.endTime, isNotNull);
        expect(profile.responseData.bodyBytes, receivedData);
      });
    });

    group('abort before response', () {
      late HttpServer successServer;
      late Uri successServerUri;
      late HttpClientRequestProfile profile;

      setUpAll(() async {
        final abortCompleter = Completer<void>();
        successServer = (await HttpServer.bind('localhost', 0))
          ..listen((request) async {
            await request.drain<void>();
            request.response.headers.set('Content-Type', 'text/plain');
            await request.response.close();
          });
        successServerUri = Uri.http('localhost:${successServer.port}');
        final client = CronetClientWithProfile.defaultCronetEngine();
        final request = AbortableStreamedRequest('GET', successServerUri,
            abortTrigger: abortCompleter.future);
        final responseFuture = client.send(request);
        abortCompleter.complete();
        unawaited(request.sink.close());
        try {
          await responseFuture;
        } on RequestAbortedException {
          // Expected failure.
        }
        profile = client.profile!;
      });
      tearDownAll(() {
        successServer.close();
      });

      test('request attributes', () async {
        expect(profile.requestData.contentLength, isNull);
        expect(profile.requestData.startTime, isNotNull);
        expect(profile.requestData.endTime, isNotNull);
        expect(profile.requestData.error, contains('aborted'));
        expect(profile.responseData.bodyBytes, isEmpty);
      });

      test('response attributes', () {
        expect(profile.responseData.bodyBytes, isEmpty);
        expect(profile.responseData.compressionState, isNull);
        expect(profile.responseData.contentLength, isNull);
        expect(profile.responseData.endTime, isNull);
        expect(profile.responseData.error, isNull);
        expect(profile.responseData.headers, isNull);
        expect(profile.responseData.isRedirect, isNull);
        expect(profile.responseData.persistentConnection, isNull);
        expect(profile.responseData.reasonPhrase, isNull);
        expect(profile.responseData.redirects, isEmpty);
        expect(profile.responseData.startTime, isNull);
        expect(profile.responseData.statusCode, isNull);
      });
    });

    group('abort during response', () {
      late HttpServer successServer;
      late Uri successServerUri;
      late HttpClientRequestProfile profile;
      RequestAbortedException? streamException;

      setUpAll(() async {
        final abortCompleter = Completer<void>();
        successServer = (await HttpServer.bind('localhost', 0))
          ..listen((request) async {
            await request.drain<void>();
            request.response.headers.set('Content-Type', 'text/plain');
            while (!abortCompleter.isCompleted) {
              request.response.write('Hello World');
              await request.response.flush();
              // Let the event loop run.
              await Future(() {});
            }
            await request.response.close();
          });
        successServerUri = Uri.http('localhost:${successServer.port}');
        final client = CronetClientWithProfile.defaultCronetEngine();
        final request = AbortableStreamedRequest('GET', successServerUri,
            abortTrigger: abortCompleter.future);
        unawaited(request.sink.close());
        final response = await client.send(request);
        var i = 0;

        try {
          await response.stream.listen((d) {
            if (++i == 2) {
              abortCompleter.complete();
            }
          }).asFuture<void>();
        } on RequestAbortedException catch (e) {
          streamException = e;
        }

        profile = client.profile!;
      });
      tearDownAll(() {
        successServer.close();
      });

      test('stream exception', () async {
        expect(streamException, isA<RequestAbortedException>());
      });

      test('request attributes', () async {
        expect(profile.requestData.contentLength, isNull);
        expect(profile.requestData.startTime, isNotNull);
        expect(profile.requestData.endTime, isNotNull);
      });

      test('response attributes', () {
        expect(profile.responseData.error, contains('aborted'));
        expect(profile.responseData.bodyBytes, isNotEmpty);
      });
    });

    group('redirects', () {
      late HttpServer successServer;
      late Uri successServerUri;
      late HttpClientRequestProfile profile;

      setUpAll(() async {
        successServer = (await HttpServer.bind('localhost', 0))
          ..listen((request) async {
            if (request.requestedUri.pathSegments.isEmpty) {
              unawaited(request.response.close());
            } else {
              final n = int.parse(request.requestedUri.pathSegments.last);
              final nextPath = n - 1 == 0 ? '' : '${n - 1}';
              unawaited(request.response
                  .redirect(successServerUri.replace(path: '/$nextPath')));
            }
          });
        successServerUri = Uri.http('localhost:${successServer.port}');
      });
      tearDownAll(() {
        successServer.close();
      });

      test('no redirects', () async {
        final client = CronetClientWithProfile.defaultCronetEngine();
        await client.get(successServerUri);
        profile = client.profile!;

        expect(profile.responseData.redirects, isEmpty);
      });

      test('follow redirects', () async {
        final client = CronetClientWithProfile.defaultCronetEngine();
        await client.send(Request('GET', successServerUri.replace(path: '/3'))
          ..followRedirects = true
          ..maxRedirects = 4);
        profile = client.profile!;

        expect(profile.requestData.followRedirects, true);
        expect(profile.requestData.maxRedirects, 4);
        expect(profile.responseData.isRedirect, false);

        expect(profile.responseData.redirects, [
          HttpProfileRedirectData(
              statusCode: 302,
              method: 'GET',
              location: successServerUri.replace(path: '/2').toString()),
          HttpProfileRedirectData(
              statusCode: 302,
              method: 'GET',
              location: successServerUri.replace(path: '/1').toString()),
          HttpProfileRedirectData(
            statusCode: 302,
            method: 'GET',
            location: successServerUri.replace(path: '/').toString(),
          )
        ]);
      });

      test('no follow redirects', () async {
        final client = CronetClientWithProfile.defaultCronetEngine();
        await client.send(Request('GET', successServerUri.replace(path: '/3'))
          ..followRedirects = false);
        profile = client.profile!;

        expect(profile.requestData.followRedirects, false);
        expect(profile.responseData.isRedirect, true);
        expect(profile.responseData.redirects, isEmpty);
      });
    });
  });
}
