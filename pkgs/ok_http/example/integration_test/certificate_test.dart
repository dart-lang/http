import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ok_http/ok_http.dart';
import 'package:test/test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:jni/jni.dart';

Future<Uint8List> loadCertificateBytes(String path) async {
  return (await rootBundle.load(path)).buffer.asUint8List();
}

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TLS', () {
    test('unknown server cert', () async {
      final serverContext = io.SecurityContext()
        ..useCertificateChainBytes(
            await loadCertificateBytes('certificates/server_chain.p12'),
            password: 'dartdart')
        ..usePrivateKeyBytes(
            await loadCertificateBytes('certificates/server_key.p12'),
            password: 'dartdart');
      final server =
          await io.SecureServerSocket.bind('localhost', 0, serverContext);
      final serverException = Completer<void>();
      server.listen((socket) async {
        serverException.complete();
      }, onError: (Object e) {
        serverException.completeError(e);
      });

      final config =
          const OkHttpClientConfiguration(validateServerCertificates: true);
      final httpClient = OkHttpClient(configuration: config);

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
            await loadCertificateBytes('certificates/server_chain.p12'),
            password: 'dartdart')
        ..usePrivateKeyBytes(
            await loadCertificateBytes('certificates/server_key.p12'),
            password: 'dartdart');
      final server =
          await io.SecureServerSocket.bind('localhost', 0, serverContext);
      server.listen((socket) async {
        socket
            .writeAll(['HTTP/1.1 200 OK', 'Content-Length: 0', '\r\n'], '\r\n');
        await socket.close();
      });

      final config =
          const OkHttpClientConfiguration(validateServerCertificates: false);
      final httpClient = OkHttpClient(configuration: config);

      expect(
          (await httpClient.get(Uri.https('localhost:${server.port}', '/')))
              .statusCode,
          200);
    });

    test('client cert', () async {
      final certBytes =
          await loadCertificateBytes('certificates/test-combined.p12');
      final serverContext = io.SecurityContext()
        ..useCertificateChainBytes(
            await loadCertificateBytes('certificates/server_chain.p12'),
            password: 'dartdart')
        ..usePrivateKeyBytes(
            await loadCertificateBytes('certificates/server_key.p12'),
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

      final (key, chain) = loadKeyFromPKC12Bytes(certBytes, '1234');
      final config = OkHttpClientConfiguration(
          clientPrivateKey: key,
          clientCertificateChain: chain,
          validateServerCertificates: false);
      final httpClient = OkHttpClient(configuration: config);

      expect(
          (await httpClient.get(Uri.https('localhost:${server.port}', '/')))
              .statusCode,
          200);
      expect((await clientCertificate.future)!.issuer,
          contains('Internet Widgits Pty Ltd'));
    });
  });
}
