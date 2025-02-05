// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ok_http/ok_http.dart';
import 'package:ok_http/src/jni/bindings.dart' as bindings;

import 'package:test/test.dart';

Future<Uint8List> loadCertificateBytes(String path) async {
  return (await rootBundle.load(path)).buffer.asUint8List();
}

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TLS', () {
    group('loadPrivateKeyAndCertificateChainFromPKCS12', () {
      test('success', () async {
        final certBytes =
            await loadCertificateBytes('test_certs/test-combined.p12');
        final (key, chain) =
            loadPrivateKeyAndCertificateChainFromPKCS12(certBytes, '1234');
        expect(
            key
                .as(bindings.Key.type)
                .getFormat()!
                .toDartString(releaseOriginal: true),
            'PKCS#8');
        expect(chain.length, 1);
        expect(chain[0].getType()!.toDartString(), 'X.509');
      });

      test('no key', () async {
        final certBytes =
            await loadCertificateBytes('test_certs/server_chain.p12');
        expect(
            () => loadPrivateKeyAndCertificateChainFromPKCS12(
                certBytes, 'dartdart'),
            throwsA(isA<ArgumentError>()
                .having((e) => e.message, 'toString', contains('no key'))));
      });

      test('no chain', () async {
        final certBytes =
            await loadCertificateBytes('test_certs/server_key.p12');
        expect(
            () => loadPrivateKeyAndCertificateChainFromPKCS12(
                certBytes, 'dartdart'),
            throwsA(isA<ArgumentError>().having((e) => e.message, 'toString',
                contains('no certificate chain'))));
      });

      test('bad password', () async {
        final certBytes =
            await loadCertificateBytes('test_certs/test-combined.p12');
        expect(
            () => loadPrivateKeyAndCertificateChainFromPKCS12(
                certBytes, 'incorrectpassword'),
            throwsA(isA<io.IOException>().having(
                (e) => e.toString(), 'toString', contains('password'))));
      });

      test('bad PKCS12 data', () async {
        final certBytes = Uint8List.fromList([1, 2, 3, 4]);
        expect(
            () =>
                loadPrivateKeyAndCertificateChainFromPKCS12(certBytes, '1234'),
            throwsA(isA<io.IOException>().having(
                (e) => e.toString(),
                'toString',
                contains('does not represent a PKCS12 key store'))));
      });
    });

    test('unknown server cert', () async {
      final serverContext = io.SecurityContext()
        ..useCertificateChainBytes(
            await loadCertificateBytes('test_certs/server_chain.p12'),
            password: 'dartdart')
        ..usePrivateKeyBytes(
            await loadCertificateBytes('test_certs/server_key.p12'),
            password: 'dartdart');
      final server =
          await io.SecureServerSocket.bind('localhost', 0, serverContext);
      final serverException = Completer<void>();
      server.listen((socket) async {
        serverException.complete();
        await socket.close();
      }, onError: (Object e) {
        serverException.completeError(e);
      });
      addTearDown(server.close);

      final config =
          const OkHttpClientConfiguration(validateServerCertificates: true);
      final httpClient = OkHttpClient(configuration: config);
      addTearDown(httpClient.close);

      expect(
          () async =>
              await httpClient.get(Uri.https('localhost:${server.port}', '/')),
          throwsA(isA<ClientException>()
              .having((e) => e.message, 'message', contains('Handshake'))));
      expect(
          () async => await serverException.future,
          throwsA(isA<io.HandshakeException>()
              .having((e) => e.message, 'message', contains('Handshake'))));
    });

    test('ignore unknown server cert', () async {
      final serverContext = io.SecurityContext()
        ..useCertificateChainBytes(
            await loadCertificateBytes('test_certs/server_chain.p12'),
            password: 'dartdart')
        ..usePrivateKeyBytes(
            await loadCertificateBytes('test_certs/server_key.p12'),
            password: 'dartdart');
      final server =
          await io.SecureServerSocket.bind('localhost', 0, serverContext);
      server.listen((socket) async {
        socket
            .writeAll(['HTTP/1.1 200 OK', 'Content-Length: 0', '\r\n'], '\r\n');
        await socket.close();
      });
      addTearDown(server.close);

      final config =
          const OkHttpClientConfiguration(validateServerCertificates: false);
      final httpClient = OkHttpClient(configuration: config);
      addTearDown(httpClient.close);

      expect(
          (await httpClient.get(Uri.https('localhost:${server.port}', '/')))
              .statusCode,
          200);
    });

    test('client cert', () async {
      final certBytes =
          await loadCertificateBytes('test_certs/test-combined.p12');
      final serverContext = io.SecurityContext()
        ..useCertificateChainBytes(
            await loadCertificateBytes('test_certs/server_chain.p12'),
            password: 'dartdart')
        ..usePrivateKeyBytes(
            await loadCertificateBytes('test_certs/server_key.p12'),
            password: 'dartdart')
        ..setTrustedCertificatesBytes(certBytes, password: '1234');

      final clientCertificate = Completer<io.X509Certificate?>();
      final server = await io.SecureServerSocket.bind(
          'localhost', 0, serverContext,
          requireClientCertificate: true);
      server.listen((socket) async {
        clientCertificate.complete(socket.peerCertificate);
        socket
            .writeAll(['HTTP/1.1 200 OK', 'Content-Length: 0', '\r\n'], '\r\n');
        await socket.close();
      });
      addTearDown(server.close);

      final (key, chain) =
          loadPrivateKeyAndCertificateChainFromPKCS12(certBytes, '1234');
      final config = OkHttpClientConfiguration(
          clientPrivateKey: key,
          clientCertificateChain: chain,
          validateServerCertificates: false);
      final httpClient = OkHttpClient(configuration: config);
      addTearDown(httpClient.close);

      expect(
          (await httpClient.get(Uri.https('localhost:${server.port}', '/')))
              .statusCode,
          200);
      expect((await clientCertificate.future)!.issuer,
          contains('Internet Widgits Pty Ltd'));
    });

    test('private key without cert chain', () async {
      final certBytes =
          await loadCertificateBytes('test_certs/test-combined.p12');

      final (key, chain) =
          loadPrivateKeyAndCertificateChainFromPKCS12(certBytes, '1234');
      final config = OkHttpClientConfiguration(clientPrivateKey: key);
      expect(() => OkHttpClient(configuration: config), throwsArgumentError);
    });

    test('private key without cert chain', () async {
      final certBytes =
          await loadCertificateBytes('test_certs/test-combined.p12');

      final (key, chain) =
          loadPrivateKeyAndCertificateChainFromPKCS12(certBytes, '1234');
      final config = OkHttpClientConfiguration(clientCertificateChain: chain);
      expect(() => OkHttpClient(configuration: config), throwsArgumentError);
    });
  });
}
