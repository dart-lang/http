// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:objective_c/objective_c.dart';
import 'package:test/test.dart';

import 'test_certificates.dart';
import 'tls_helpers.dart';

const _nsurlErrorCancelled = -999;
const _nsurlErrorServerCertificateUntrusted = -1202;

/// Accepts the server trust if it chains to [anchor].
(NSURLSessionAuthChallengeDisposition, URLCredential?) _trustAnchor(
  URLAuthenticationChallenge challenge,
  SecCertificate anchor,
) {
  final trust = challenge.protectionSpace.serverTrust;
  if (trust == null) {
    return (
      NSURLSessionAuthChallengeDisposition
          .NSURLSessionAuthChallengePerformDefaultHandling,
      null,
    );
  }
  trust.setAnchorCertificates([anchor]);
  if (trust.evaluate().trusted) {
    return (
      NSURLSessionAuthChallengeDisposition
          .NSURLSessionAuthChallengeUseCredential,
      URLCredential.forTrust(trust),
    );
  }
  return (
    NSURLSessionAuthChallengeDisposition
        .NSURLSessionAuthChallengeCancelAuthenticationChallenge,
    null,
  );
}

/// Executes a GET request for [uri] using [session].
Future<(URLResponse?, NSData?, NSError?)> get(URLSession session, Uri uri) {
  final c = Completer<(URLResponse?, NSData?, NSError?)>();
  session
      .dataTaskWithCompletionHandler(
        URLRequest.fromUrl(uri),
        (data, response, error) => c.complete((response, data, error)),
      )
      .resume();
  return c.future;
}

void testSecCertificate() {
  group('SecCertificate', () {
    test('fromDer and der', () {
      final der = pemToDer(testCaCertificatePem);
      final certificate = SecCertificate.fromDer(der);
      expect(certificate.der, der);
      expect(certificate.subjectSummary, 'cupertino_http Test CA');
      expect(certificate.toString(), contains('cupertino_http Test CA'));
    });

    test('fromDer invalid', () {
      expect(
        () => SecCertificate.fromDer(Uint8List.fromList([1, 2, 3])),
        throwsArgumentError,
      );
    });
  });
}

void testOnChallenge(URLSessionConfiguration Function() config) {
  group('onChallenge', () {
    late HttpServer server;
    late Uri uri;
    final testCa = SecCertificate.fromDer(pemToDer(testCaCertificatePem));
    final otherCa = SecCertificate.fromDer(pemToDer(otherCaCertificatePem));

    setUp(() async {
      server = await startSecureServer();
      uri = Uri.https('localhost:${server.port}', '/');
    });
    tearDown(() => server.close(force: true));

    test('server trust challenge', () async {
      late URLAuthenticationChallenge actualChallenge;
      late SecTrust actualTrust;
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, challenge) {
          actualChallenge = challenge;
          actualTrust = challenge.protectionSpace.serverTrust!;
          return (
            NSURLSessionAuthChallengeDisposition
                .NSURLSessionAuthChallengePerformDefaultHandling,
            null,
          );
        },
      );
      addTearDown(session.finishTasksAndInvalidate);

      await get(session, uri);
      final space = actualChallenge.protectionSpace;
      expect(space.authenticationMethod, NSURLAuthenticationMethodServerTrust);
      expect(space.host, 'localhost');
      expect(space.port, server.port);
      expect(space.protocol, 'https');
      expect(space.isProxy, false);
      expect(actualChallenge.previousFailureCount, 0);
      expect(actualTrust.certificateChain.first.subjectSummary, 'localhost');
    });

    test('perform default handling', () async {
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, c) => (
          NSURLSessionAuthChallengeDisposition
              .NSURLSessionAuthChallengePerformDefaultHandling,
          null,
        ),
      );
      addTearDown(session.finishTasksAndInvalidate);

      final (response, _, error) = await get(session, uri);
      expect(response, isNull);
      expect(error!.code, _nsurlErrorServerCertificateUntrusted);
    });

    test('trusted anchor', () async {
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, challenge) => _trustAnchor(challenge, testCa),
      );
      addTearDown(session.finishTasksAndInvalidate);

      final (response, data, error) = await get(session, uri);
      expect(error, isNull);
      expect((response as HTTPURLResponse).statusCode, 200);
      expect(utf8.decode(data!.toList()), 'Hello World');
    });

    test('async callback', () async {
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, challenge) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return _trustAnchor(challenge, testCa);
        },
      );
      addTearDown(session.finishTasksAndInvalidate);

      final (response, _, error) = await get(session, uri);
      expect(error, isNull);
      expect((response as HTTPURLResponse).statusCode, 200);
    });

    test('networkFetchAllowed', () async {
      late List<bool> values;
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, challenge) {
          final trust = challenge.protectionSpace.serverTrust!;
          values = [trust.networkFetchAllowed];
          trust.networkFetchAllowed = false;
          values.add(trust.networkFetchAllowed);
          trust.networkFetchAllowed = true;
          values.add(trust.networkFetchAllowed);
          return (
            NSURLSessionAuthChallengeDisposition
                .NSURLSessionAuthChallengeCancelAuthenticationChallenge,
            null,
          );
        },
      );
      addTearDown(session.finishTasksAndInvalidate);

      await get(session, uri);
      // Network fetch is allowed by default for TLS server trusts.
      expect(values, [true, false, true]);
    });

    test('network fetch not allowed', () async {
      late ({bool trusted, NSError? error}) result;
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, challenge) {
          final trust = challenge.protectionSpace.serverTrust!
            ..networkFetchAllowed = false
            ..setAnchorCertificates([testCa]);
          result = trust.evaluate();
          return result.trusted
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
        },
      );
      addTearDown(session.finishTasksAndInvalidate);

      final (response, _, error) = await get(session, uri);
      expect(result.trusted, true);
      expect(error, isNull);
      expect((response as HTTPURLResponse).statusCode, 200);
    });

    test('certificateChain evaluates the trust', () async {
      late List<String?> chain;
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, challenge) {
          final trust = challenge.protectionSpace.serverTrust!
            ..setAnchorCertificates([testCa]);
          // `evaluate` is not called but the chain includes the anchor.
          chain = [for (final c in trust.certificateChain) c.subjectSummary];
          return (
            NSURLSessionAuthChallengeDisposition
                .NSURLSessionAuthChallengeCancelAuthenticationChallenge,
            null,
          );
        },
      );
      addTearDown(session.finishTasksAndInvalidate);

      await get(session, uri);
      expect(chain, ['localhost', 'cupertino_http Test CA']);
    });

    test('evaluate with trusted anchor', () async {
      late ({bool trusted, NSError? error}) result;
      late List<SecCertificate> chain;
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, challenge) {
          final trust = challenge.protectionSpace.serverTrust!
            ..setAnchorCertificates([testCa]);
          result = trust.evaluate();
          chain = trust.certificateChain;
          return (
            NSURLSessionAuthChallengeDisposition
                .NSURLSessionAuthChallengeCancelAuthenticationChallenge,
            null,
          );
        },
      );
      addTearDown(session.finishTasksAndInvalidate);

      await get(session, uri);
      expect(
        result.trusted,
        true,
        reason: result.error?.localizedDescription.toDartString(),
      );
      expect(result.error, isNull);
      expect(chain.map((c) => c.subjectSummary), [
        'localhost',
        'cupertino_http Test CA',
      ]);
      expect(chain.last.der, testCa.der);
    });

    test('evaluate with untrusted anchor', () async {
      late ({bool trusted, NSError? error}) result;
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, challenge) {
          final trust = challenge.protectionSpace.serverTrust!
            ..setAnchorCertificates([otherCa]);
          result = trust.evaluate();
          return (
            NSURLSessionAuthChallengeDisposition
                .NSURLSessionAuthChallengeCancelAuthenticationChallenge,
            null,
          );
        },
      );
      addTearDown(session.finishTasksAndInvalidate);

      final (response, _, error) = await get(session, uri);
      expect(result.trusted, false);
      expect(result.error, isNotNull);
      expect(response, isNull);
      expect(error, isNotNull);
    });

    test('evaluate with system anchors', () async {
      late ({bool trusted, NSError? error}) result;
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, challenge) {
          result = challenge.protectionSpace.serverTrust!.evaluate();
          return (
            NSURLSessionAuthChallengeDisposition
                .NSURLSessionAuthChallengeCancelAuthenticationChallenge,
            null,
          );
        },
      );
      addTearDown(session.finishTasksAndInvalidate);

      await get(session, uri);
      expect(result.trusted, false);
      expect(result.error, isNotNull);
    });

    test('anchor and system anchors', () async {
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, challenge) {
          final trust = challenge.protectionSpace.serverTrust!
            ..setAnchorCertificates([testCa])
            ..setAnchorCertificatesOnly(false);
          final result = trust.evaluate();
          return result.trusted
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
        },
      );
      addTearDown(session.finishTasksAndInvalidate);

      final (response, _, error) = await get(session, uri);
      expect(error, isNull);
      expect((response as HTTPURLResponse).statusCode, 200);
    });

    test('pinned leaf certificate', () async {
      // Accept the server if it presents exactly the expected certificate.
      // The TLS handshake verifies that the server has the corresponding
      // private key.
      final expected = pemToDer(serverCertificatePem);
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, challenge) {
          final trust = challenge.protectionSpace.serverTrust!;
          final leaf = trust.certificateChain.first;
          if (listEquals(leaf.der, expected)) {
            return (
              NSURLSessionAuthChallengeDisposition
                  .NSURLSessionAuthChallengeUseCredential,
              URLCredential.forTrust(trust),
            );
          }
          return (
            NSURLSessionAuthChallengeDisposition
                .NSURLSessionAuthChallengeCancelAuthenticationChallenge,
            null,
          );
        },
      );
      addTearDown(session.finishTasksAndInvalidate);

      final (response, _, error) = await get(session, uri);
      expect(error, isNull);
      expect((response as HTTPURLResponse).statusCode, 200);
    });

    test('cancel', () async {
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, c) => (
          NSURLSessionAuthChallengeDisposition
              .NSURLSessionAuthChallengeCancelAuthenticationChallenge,
          null,
        ),
      );
      addTearDown(session.finishTasksAndInvalidate);

      final (response, _, error) = await get(session, uri);
      expect(response, isNull);
      expect(error!.code, _nsurlErrorCancelled);
    });

    // NOTE: For a server that the system trusts, these dispositions fall back
    // to default handling (i.e. the server is trusted). Only cancelling the
    // challenge reliably rejects a server.
    test('reject protection space', () async {
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, c) => (
          NSURLSessionAuthChallengeDisposition
              .NSURLSessionAuthChallengeRejectProtectionSpace,
          null,
        ),
      );
      addTearDown(session.finishTasksAndInvalidate);

      final (response, _, error) = await get(session, uri);
      expect(response, isNull);
      expect(error!.code, _nsurlErrorServerCertificateUntrusted);
    });

    test('use credential without credential', () async {
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, c) => (
          NSURLSessionAuthChallengeDisposition
              .NSURLSessionAuthChallengeUseCredential,
          null,
        ),
      );
      addTearDown(session.finishTasksAndInvalidate);

      final (response, _, error) = await get(session, uri);
      expect(response, isNull);
      expect(error!.code, _nsurlErrorServerCertificateUntrusted);
    });

    test('throws', () async {
      final errors = <Object>[];
      final result = await runZonedGuarded(() async {
        final session = URLSession.sessionWithConfiguration(
          config(),
          onChallenge: (s, t, c) => throw UnsupportedError('test'),
        );
        try {
          return await get(session, uri);
        } finally {
          session.finishTasksAndInvalidate();
        }
      }, (e, s) => errors.add(e));

      final (response, _, error) = result!;
      expect(response, isNull);
      expect(error!.code, _nsurlErrorCancelled);
      expect(errors, [isA<UnsupportedError>()]);
    });

    test('async throws', () async {
      final errors = <Object>[];
      final result = await runZonedGuarded(() async {
        final session = URLSession.sessionWithConfiguration(
          config(),
          onChallenge: (s, t, c) async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            throw UnsupportedError('test');
          },
        );
        try {
          return await get(session, uri);
        } finally {
          session.finishTasksAndInvalidate();
        }
      }, (e, s) => errors.add(e));

      final (response, _, error) = result!;
      expect(response, isNull);
      expect(error!.code, _nsurlErrorCancelled);
      expect(errors, [isA<UnsupportedError>()]);
    });

    test('not called for http', () async {
      final httpServer = await HttpServer.bind('localhost', 0)
        ..listen((request) async {
          await request.drain<void>();
          await request.response.close();
        });
      addTearDown(httpServer.close);
      var called = false;
      final session = URLSession.sessionWithConfiguration(
        config(),
        onChallenge: (s, t, c) {
          called = true;
          return (
            NSURLSessionAuthChallengeDisposition
                .NSURLSessionAuthChallengePerformDefaultHandling,
            null,
          );
        },
      );
      addTearDown(session.finishTasksAndInvalidate);

      final (response, _, error) = await get(
        session,
        Uri.http('localhost:${httpServer.port}', '/'),
      );
      expect(error, isNull);
      expect((response as HTTPURLResponse).statusCode, 200);
      expect(called, false);
    });

    test('task delegate', () async {
      // The session has no delegate, so the server trust challenge is
      // delivered to the task delegate. This is how `CupertinoClient` works.
      final session = URLSession.sessionWithConfiguration(config());
      addTearDown(session.finishTasksAndInvalidate);
      final c = Completer<(URLResponse?, NSError?)>();
      URLResponse? response;

      session.dataTaskWithRequest(URLRequest.fromUrl(uri))
        ..taskDelegate = URLSessionTask.delegate(
          onChallenge: (s, t, challenge) => _trustAnchor(challenge, testCa),
          onResponse: (s, t, r) {
            response = r;
            return NSURLSessionResponseDisposition.NSURLSessionResponseAllow;
          },
          onComplete: (s, t, error) => c.complete((response, error)),
        )
        ..resume();

      final (actualResponse, error) = await c.future;
      expect(error, isNull);
      expect((actualResponse as HTTPURLResponse).statusCode, 200);
    });
  });
}

void main() {
  testSecCertificate();

  group('defaultSessionConfiguration', () {
    testOnChallenge(URLSessionConfiguration.defaultSessionConfiguration);
  });

  group('ephemeralSessionConfiguration', () {
    testOnChallenge(URLSessionConfiguration.ephemeralSessionConfiguration);
  });
}
