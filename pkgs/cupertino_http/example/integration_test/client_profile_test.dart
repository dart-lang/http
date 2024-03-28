// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cupertino_http/src/cupertino_client.dart';
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

    group('non-streamed POST', () {
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
        final client = CupertinoClientWithProfile.defaultSessionConfiguration();
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
            containsPair('package', 'package:cupertino_http'));
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

    group('streaming POST request', () {
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
        final client = CupertinoClientWithProfile.defaultSessionConfiguration();
        final request = StreamedRequest('POST', successServerUri);
        final stream = () async* {
          for (var i = 0; i < 1000; ++i) {
            await Future<void>.delayed(const Duration());
            // The request has started but not finished.
            expect(client.profile!.requestData.startTime, isNotNull);
            expect(client.profile!.requestData.endTime, isNull);
            expect(client.profile!.responseData.startTime, isNull);
            expect(client.profile!.responseData.endTime, isNull);
            yield 'Hello'.codeUnits;
          }
        }();
        unawaited(
            request.sink.addStream(stream).then((_) => request.sink.close()));

        await client.send(request);
        profile = client.profile!;
      });
      tearDownAll(() {
        successServer.close();
      });

      test('request attributes', () async {
        expect(profile.requestData.bodyBytes, ('Hello' * 1000).codeUnits);
        expect(profile.requestData.contentLength, isNull);
        expect(profile.requestData.endTime, isNotNull);
        expect(profile.requestData.startTime, isNotNull);
        expect(profile.requestData.headers, isNot(contains('Content-Length')));
      });
    });

    group('failed POST request', () {
      late HttpClientRequestProfile profile;

      setUpAll(() async {
        final client = CupertinoClientWithProfile.defaultSessionConfiguration();
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
            containsPair('package', 'package:cupertino_http'));
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
        final client = CupertinoClientWithProfile.defaultSessionConfiguration();

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
            containsPair('package', 'package:cupertino_http'));
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
        final client = CupertinoClientWithProfile.defaultSessionConfiguration();
        await client.get(successServerUri);
        profile = client.profile!;

        expect(profile.responseData.redirects, isEmpty);
      });

      test('follow redirects', () async {
        final client = CupertinoClientWithProfile.defaultSessionConfiguration();
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
        final client = CupertinoClientWithProfile.defaultSessionConfiguration();
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
