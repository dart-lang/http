// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart';
import 'package:objective_c/objective_c.dart';
import 'package:test/test.dart';

import 'test_certificates.dart';
import 'tls_helpers.dart';

const _nsurlErrorServerCertificateUntrusted = -1202;

void main() {
  group('onChallenge', () {
    late HttpServer server;
    late Uri uri;
    final testCa = SecCertificate.fromDer(pemToDer(testCaCertificatePem));

    setUp(() async {
      server = await startSecureServer();
      uri = Uri.https('localhost:${server.port}', '/');
    });
    tearDown(() => server.close(force: true));

    /// Trusts servers with certificates issued by [testCaCertificatePem].
    (NSURLSessionAuthChallengeDisposition, URLCredential?) trustTestCa(
      URLSession session,
      URLSessionTask task,
      URLAuthenticationChallenge challenge,
    ) {
      final trust = challenge.protectionSpace.serverTrust;
      if (trust == null) {
        return (
          NSURLSessionAuthChallengeDisposition
              .NSURLSessionAuthChallengePerformDefaultHandling,
          null,
        );
      }
      trust.setAnchorCertificates([testCa]);
      return trust.evaluate().trusted
          ? (
              NSURLSessionAuthChallengeDisposition
                  .NSURLSessionAuthChallengeUseCredential,
              URLCredential.forTrust(trust),
            )
          : (
              NSURLSessionAuthChallengeDisposition
                  .NSURLSessionAuthChallengeCancelAuthenticationChallenge,
              null,
            );
    }

    CupertinoClient createClient(OnChallenge? onChallenge) {
      final client = CupertinoClient.fromSessionConfiguration(
        URLSessionConfiguration.ephemeralSessionConfiguration(),
        onChallenge: onChallenge,
      );
      addTearDown(client.close);
      return client;
    }

    test('no onChallenge', () async {
      final client = createClient(null);
      await expectLater(
        client.get(uri),
        throwsA(
          isA<NSErrorClientException>().having(
            (e) => e.error.code,
            'error.code',
            _nsurlErrorServerCertificateUntrusted,
          ),
        ),
      );
    });

    test('trusted', () async {
      final client = createClient(trustTestCa);
      final response = await client.get(uri);
      expect(response.statusCode, 200);
      expect(response.body, 'Hello World');
    });

    test('async onChallenge', () async {
      final client = createClient((session, task, challenge) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return trustTestCa(session, task, challenge);
      });
      final response = await client.get(uri);
      expect(response.statusCode, 200);
    });

    test('onChallenge arguments', () async {
      late URLSessionTask actualTask;
      late URLAuthenticationChallenge actualChallenge;
      final client = createClient((session, task, challenge) {
        actualTask = task;
        actualChallenge = challenge;
        return trustTestCa(session, task, challenge);
      });

      await client.get(uri);
      expect(actualTask.originalRequest!.url, uri);
      final space = actualChallenge.protectionSpace;
      expect(space.authenticationMethod, NSURLAuthenticationMethodServerTrust);
      expect(space.host, 'localhost');
      expect(space.port, server.port);
      expect(
        space.serverTrust!.certificateChain.first.subjectSummary,
        'localhost',
      );
    });

    test('cancelled', () async {
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
                (e) => e,
                'exception',
                isNot(isA<RequestAbortedException>()),
              )
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

    test('perform default handling', () async {
      final client = createClient(
        (session, task, challenge) => (
          NSURLSessionAuthChallengeDisposition
              .NSURLSessionAuthChallengePerformDefaultHandling,
          null,
        ),
      );
      await expectLater(
        client.get(uri),
        throwsA(
          isA<NSErrorClientException>().having(
            (e) => e.error.code,
            'error.code',
            _nsurlErrorServerCertificateUntrusted,
          ),
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

    test('pinned leaf certificate', () async {
      final expected = pemToDer(serverCertificatePem);
      final client = createClient((session, task, challenge) {
        final trust = challenge.protectionSpace.serverTrust!;
        return listEquals(trust.certificateChain.first.der, expected)
            ? (
                NSURLSessionAuthChallengeDisposition
                    .NSURLSessionAuthChallengeUseCredential,
                URLCredential.forTrust(trust),
              )
            : (
                NSURLSessionAuthChallengeDisposition
                    .NSURLSessionAuthChallengeCancelAuthenticationChallenge,
                null,
              );
      });
      final response = await client.get(uri);
      expect(response.statusCode, 200);
    });

    test('called once per connection', () async {
      var calls = 0;
      final client = createClient((session, task, challenge) {
        ++calls;
        return trustTestCa(session, task, challenge);
      });

      await client.get(uri);
      await client.get(uri);
      expect(calls, 1);
    });

    test('not called for http', () async {
      final httpServer = await HttpServer.bind('localhost', 0)
        ..listen((request) async {
          await request.drain<void>();
          await request.response.close();
        });
      addTearDown(httpServer.close);
      var called = false;
      final client = createClient((session, task, challenge) {
        called = true;
        return (
          NSURLSessionAuthChallengeDisposition
              .NSURLSessionAuthChallengePerformDefaultHandling,
          null,
        );
      });

      final response = await client.get(
        Uri.http('localhost:${httpServer.port}', '/'),
      );
      expect(response.statusCode, 200);
      expect(called, false);
    });

    test('http basic challenge', () async {
      final httpServer = await HttpServer.bind('localhost', 0)
        ..listen((request) async {
          await request.drain<void>();
          request.response
            ..statusCode = HttpStatus.unauthorized
            ..headers.set(
              HttpHeaders.wwwAuthenticateHeader,
              'Basic realm="test"',
            );
          await request.response.close();
        });
      addTearDown(httpServer.close);
      final spaces = <URLProtectionSpace>[];
      final client = createClient((session, task, challenge) {
        spaces.add(challenge.protectionSpace);
        return (
          NSURLSessionAuthChallengeDisposition
              .NSURLSessionAuthChallengePerformDefaultHandling,
          null,
        );
      });

      final response = await client.get(
        Uri.http('localhost:${httpServer.port}', '/'),
      );
      expect(response.statusCode, 401);
      expect(spaces, hasLength(1));
      expect(
        spaces.single.authenticationMethod,
        NSURLAuthenticationMethodHTTPBasic,
      );
      expect(spaces.single.realm, 'test');
    });

    test('aborted during onChallenge', () async {
      final abortTrigger = Completer<void>();
      final client = createClient((session, task, challenge) async {
        abortTrigger.complete();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return trustTestCa(session, task, challenge);
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
