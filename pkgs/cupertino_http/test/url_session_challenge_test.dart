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

/// Trusts the server without evaluating its certificate chain.
(NSURLSessionAuthChallengeDisposition, URLCredential?) _trustServer(
  URLSession session,
  URLSessionTask task,
  URLAuthenticationChallenge challenge,
) => (
  NSURLSessionAuthChallengeDisposition.NSURLSessionAuthChallengeUseCredential,
  URLCredential.forTrust(challenge.protectionSpace.serverTrust!),
);

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

/// Calls [inspect] with the [SecTrust] of a server whose certificate is issued
/// by [testCaCertificatePem].
Future<void> withServerTrust(void Function(SecTrust trust) inspect) async {
  final server = await startSecureServer();
  final session = URLSession.sessionWithConfiguration(
    URLSessionConfiguration.ephemeralSessionConfiguration(),
    onChallenge: (s, t, challenge) {
      inspect(challenge.protectionSpace.serverTrust!);
      return (
        NSURLSessionAuthChallengeDisposition
            .NSURLSessionAuthChallengeCancelAuthenticationChallenge,
        null,
      );
    },
  );
  try {
    await get(session, Uri.https('localhost:${server.port}', '/'));
  } finally {
    session.finishTasksAndInvalidate();
    await server.close(force: true);
  }
}

void main() {
  final testCa = SecCertificate.fromDer(pemToDer(testCaCertificatePem));
  final otherCa = SecCertificate.fromDer(pemToDer(otherCaCertificatePem));

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

  group('SecTrust', () {
    test('networkFetchAllowed', () async {
      late List<bool> values;
      await withServerTrust((trust) {
        trust.networkFetchAllowed = false;
        values = [trust.networkFetchAllowed];
        trust.networkFetchAllowed = true;
        values.add(trust.networkFetchAllowed);
      });
      expect(values, [false, true]);
    });

    test('evaluate trusted', () async {
      late ({bool trusted, NSError? error}) result;
      late List<SecCertificate> chain;
      await withServerTrust((trust) {
        trust.setAnchorCertificates([testCa]);
        result = trust.evaluate();
        chain = trust.certificateChain;
      });
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
    });

    test('evaluate untrusted', () async {
      late ({bool trusted, NSError? error}) result;
      await withServerTrust((trust) {
        trust.setAnchorCertificates([otherCa]);
        result = trust.evaluate();
      });
      expect(result.trusted, false);
      expect(result.error, isNotNull);
    });

    test('setAnchorCertificatesOnly', () async {
      late bool trusted;
      await withServerTrust((trust) {
        trust
          ..setAnchorCertificates([testCa])
          ..setAnchorCertificatesOnly(false);
        trusted = trust.evaluate().trusted;
      });
      expect(trusted, true);
    });
  });

  group('onChallenge', () {
    late HttpServer server;
    late Uri uri;

    setUp(() async {
      server = await startSecureServer();
      uri = Uri.https('localhost:${server.port}', '/');
    });
    tearDown(() => server.close(force: true));

    URLSession createSession(OnChallenge onChallenge) {
      final session = URLSession.sessionWithConfiguration(
        URLSessionConfiguration.ephemeralSessionConfiguration(),
        onChallenge: onChallenge,
      );
      addTearDown(session.finishTasksAndInvalidate);
      return session;
    }

    test('challenge', () async {
      late URLSessionTask actualTask;
      late URLAuthenticationChallenge actualChallenge;
      final session = createSession((s, task, challenge) {
        actualTask = task;
        actualChallenge = challenge;
        return _trustServer(s, task, challenge);
      });

      await get(session, uri);
      expect(actualTask.originalRequest!.url, uri);
      final space = actualChallenge.protectionSpace;
      expect(space.authenticationMethod, NSURLAuthenticationMethodServerTrust);
      expect(space.host, 'localhost');
      expect(space.port, server.port);
      expect(space.protocol, 'https');
      expect(space.isProxy, false);
      expect(space.serverTrust, isNotNull);
      expect(actualChallenge.previousFailureCount, 0);
    });

    test('use credential', () async {
      final session = createSession(_trustServer);
      final (response, data, error) = await get(session, uri);
      expect(error, isNull);
      expect((response as HTTPURLResponse).statusCode, 200);
      expect(utf8.decode(data!.toList()), 'Hello World');
    });

    test('async', () async {
      final session = createSession((s, t, challenge) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _trustServer(s, t, challenge);
      });
      final (response, _, error) = await get(session, uri);
      expect(error, isNull);
      expect((response as HTTPURLResponse).statusCode, 200);
    });

    test('throws', () async {
      final errors = <Object>[];
      final result = await runZonedGuarded(
        () => get(createSession((s, t, c) => throw UnsupportedError('x')), uri),
        (e, s) => errors.add(e),
      );

      final (response, _, error) = result!;
      expect(response, isNull);
      expect(error!.code, _nsurlErrorCancelled);
      expect(errors, [isA<UnsupportedError>()]);
    });

    test('async throws', () async {
      final errors = <Object>[];
      final result = await runZonedGuarded(
        () => get(
          createSession((s, t, c) async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            throw UnsupportedError('x');
          }),
          uri,
        ),
        (e, s) => errors.add(e),
      );

      final (response, _, error) = result!;
      expect(response, isNull);
      expect(error!.code, _nsurlErrorCancelled);
      expect(errors, [isA<UnsupportedError>()]);
    });

    test('task delegate', () async {
      final session = URLSession.sessionWithConfiguration(
        URLSessionConfiguration.ephemeralSessionConfiguration(),
      );
      addTearDown(session.finishTasksAndInvalidate);
      final c = Completer<(URLResponse?, NSError?)>();
      URLResponse? response;

      session.dataTaskWithRequest(URLRequest.fromUrl(uri))
        ..taskDelegate = URLSessionTask.delegate(
          onChallenge: _trustServer,
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
