// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

import 'tls_helpers.dart';

/// Trusts the server without evaluating its certificate chain.
(NSURLSessionAuthChallengeDisposition, URLCredential?) _trustServer(
  URLSession session,
  URLSessionTask task,
  URLAuthenticationChallenge challenge,
) => (
  NSURLSessionAuthChallengeDisposition.NSURLSessionAuthChallengeUseCredential,
  URLCredential.forTrust(challenge.protectionSpace.serverTrust!),
);

void main() {
  group('onChallenge', () {
    late HttpServer server;
    late Uri uri;

    setUp(() async {
      server = await startSecureServer();
      uri = Uri.https('localhost:${server.port}', '/');
    });
    tearDown(() => server.close(force: true));

    CupertinoClient createClient(OnChallenge? onChallenge) {
      final client = CupertinoClient.fromSessionConfiguration(
        URLSessionConfiguration.ephemeralSessionConfiguration(),
        onChallenge: onChallenge,
      );
      addTearDown(client.close);
      return client;
    }

    test('not set', () async {
      final client = createClient(null);
      await expectLater(
        client.get(uri),
        throwsA(isA<NSErrorClientException>()),
      );
    });

    test('arguments', () async {
      late URLSessionTask actualTask;
      late URLAuthenticationChallenge actualChallenge;
      final client = createClient((session, task, challenge) {
        actualTask = task;
        actualChallenge = challenge;
        return _trustServer(session, task, challenge);
      });

      await client.get(uri);
      expect(actualTask.originalRequest!.url, uri);
      expect(
        actualChallenge.protectionSpace.authenticationMethod,
        NSURLAuthenticationMethodServerTrust,
      );
    });

    test('use credential', () async {
      final client = createClient(_trustServer);
      final response = await client.get(uri);
      expect(response.statusCode, 200);
      expect(response.body, 'Hello World');
    });

    test('async', () async {
      final client = createClient((session, task, challenge) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _trustServer(session, task, challenge);
      });
      final response = await client.get(uri);
      expect(response.statusCode, 200);
    });

    test('cancel', () async {
      final client = createClient(
        (session, task, challenge) => (
          NSURLSessionAuthChallengeDisposition
              .NSURLSessionAuthChallengeCancelAuthenticationChallenge,
          null,
        ),
      );
      await expectLater(
        client.get(uri),
        throwsA(
          isA<ClientException>()
              .having(
                (e) => e.message,
                'message',
                'onChallenge cancelled the '
                    'NSURLAuthenticationMethodServerTrust challenge for '
                    'localhost:${server.port}',
              )
              .having((e) => e.uri, 'uri', uri),
        ),
      );
    });

    test('throws', () async {
      final client = createClient(
        (session, task, challenge) => throw StateError('x'),
      );
      await expectLater(client.get(uri), throwsStateError);
    });

    test('async throws', () async {
      final client = createClient((session, task, challenge) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        throw StateError('x');
      });
      await expectLater(client.get(uri), throwsStateError);
    });

    test('aborted', () async {
      final abortTrigger = Completer<void>();
      final client = createClient((session, task, challenge) async {
        abortTrigger.complete();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return _trustServer(session, task, challenge);
      });
      final request = AbortableRequest(
        'GET',
        uri,
        abortTrigger: abortTrigger.future,
      );
      await expectLater(
        client.send(request),
        throwsA(isA<RequestAbortedException>()),
      );
    });
  });
}
