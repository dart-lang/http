import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ok_http/ok_http.dart';
import 'package:test/test.dart';
import 'package:flutter/services.dart' show rootBundle;

List<int> key = '''-----BEGIN PRIVATE KEY-----
MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDEEY2eWBX1rTDg
sAWheltKiAHREteaqX4iaGwF6/TC6kMJajZQreySsib+lQ+FTLtMlPWorR5jMfsA
6PDocRpK2zOObTqdVqJAiodUi0ovds7wgaN7XnUfpPo8NDMA2tV8Bn2mfKWgC3Qk
UMPCDBkLqiYUuR6j5QJ4Vz2OFV5g1iR1HzgQgr4pbNjkUJJesr0r1J1a25YbYdLI
vzss+aHBTWD+9HYfgWsfJGI3UFgczoAJbKSIHYqDGsSKZMgmtixyyEjTDc6OAqjk
10jhYdxdglXpTPOWP5YnwWsy8VbU1ozu93LlWkbbef95FD/XGH/ynglIe1laZwEX
dyxOzT3bAgMBAAECggEAHGsa5reHv0syCW8Z8dTFRKE/+ijL/UvRz3TpK1aO7G19
9/BgHQOIhZ6yzjWWwVBk2W3ByYgGHoSRCAm7WUWDdRQefedRFpsG+2nYwaVKxGRp
DC0OIASJ32NPLci3F8mgJdDfB3GLpA3k8JqQNSEBxFIOIPTP/xtjZ0Pl1SE9w7Uk
8pwuJPJDPSAamguSNY5+HHcyta/i7Zsv2/S4BdV8Q8WQeCc6hcR3Zka1H0txgk8o
qUurU2ApdnzINQ7ki0+D6CuVXEivmL/kPivQg0/khIQp1IXhdYdWCMKSUr1vkoAK
0zc6H5DlDvdQPrjqdLGOUlVx5JnjTYd68/Wqje76eQKBgQD0uNR2yJYxmQmLC1y6
TLXxvm0OOlmUiNMZgLOwDNdjXvOH/emtpHyyKhHpc3kzNK3xsNxyAYJRlaIUylj0
C9dsipj+QTb4ICu0GlbLXsXN5iM592igoS4kMnP9KbzSc93k9BvMhh1emO8i3GB7
v/1Cf/z+gP+viLMaPEFqKxI8FwKBgQDNGrjabA2jkawanHHUUhwscwB4RrvuuJTG
Zv7L7QXBMYx7CUwJztV5amkUNrbBW/67/MMQB0Djv1pgMo4QCWeftb9oHFXGu3hV
kUj7Or/Z2TWYtLIdxgTDbRRtit57z3NaCHCDgQhyAZUY3y8cvXFYdHDnJlqLTN77
bzQub7BS3QKBgHtUep6yUB8GxSxxuXWaG0eNdGBrP6H/ooODvQrILfRCcfDjIdUE
xGL1mLlSHI6VyeO4AiDiac673kckAtha72IgJyJbs1wwulW1wHAVfxJZHP+lk/D/
ycUsOBAp7KMTCYzNCQV1wW9fG4UyEt3Kz9OntNR+Jl1MQxbBryXWNwZZAoGAO48x
9MOB5mjL2GJrr6M0aTfv//1SX40cLs0D2oX2sNZJnATkHskANqTO5L7KrTWgsEhD
AKmKj1gmz15+4GtKuxcVAQ+RXQddd0OcNNAnnAQ2SyTVwE2bXoCTeQfleYCRV6ix
u45BvJF3EWTmEmt0uaH+kzERA/iLm+n79iwawMUCgYB7s6ZkEbyZbJDDT8MXU/37
vvLo5/sPzJ6hMPIrWbKybmUfKAMBkXYV90bVfBxim+PEGyiIWSHlXRCgHLUc/C7C
4s8ouWDR2F3zUWjadzRsPI58qWL9yVa5aGoSzoJu2qyuX4QKS8hOehxVMzIB4Mrf
Hh0tvtntgpJAW2TwXMVxCw==
-----END PRIVATE KEY-----'''
    .codeUnits;

List<int> cert = '''-----BEGIN CERTIFICATE-----
MIIDNjCCAh6gAwIBAgIUe+E1Xth9TMlsYY7qmf9zlfC1Ms0wDQYJKoZIhvcNAQEL
BQAwFDESMBAGA1UEAwwJbG9jYWxob3N0MCAXDTE4MTIzMTIzMDAxMVoYDzIxMTgx
MjA3MjMwMDExWjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQDEEY2eWBX1rTDgsAWheltKiAHREteaqX4iaGwF6/TC
6kMJajZQreySsib+lQ+FTLtMlPWorR5jMfsA6PDocRpK2zOObTqdVqJAiodUi0ov
ds7wgaN7XnUfpPo8NDMA2tV8Bn2mfKWgC3QkUMPCDBkLqiYUuR6j5QJ4Vz2OFV5g
1iR1HzgQgr4pbNjkUJJesr0r1J1a25YbYdLIvzss+aHBTWD+9HYfgWsfJGI3UFgc
zoAJbKSIHYqDGsSKZMgmtixyyEjTDc6OAqjk10jhYdxdglXpTPOWP5YnwWsy8VbU
1ozu93LlWkbbef95FD/XGH/ynglIe1laZwEXdyxOzT3bAgMBAAGjfjB8MB0GA1Ud
DgQWBBS/3CUrYgiD2qwdEDStghi+X3+4pzAfBgNVHSMEGDAWgBS/3CUrYgiD2qwd
EDStghi+X3+4pzAPBgNVHRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMB
MBQGA1UdEQQNMAuCCWxvY2FsaG9zdDANBgkqhkiG9w0BAQsFAAOCAQEAu5adpS/h
bWXYaDLW5JGZAiOVVkMDhspJDdPwDHUTqMPj3V6aaecZTc46Q7TLEkLxIjU5OjvR
ZHh3vo9X4S84Yf7NHv8eX50MK/RrzZolUROhZ6gtYZKkdZtjQKQd62ih5EB6gNnZ
+IW9nedg7Sae2Yh22jDC9Tc+dbvroOd7IUwL9gVSCcwiqVjvuWkDa7jqjnRp4sog
yY1Obr14tmUMgR73Db7q3g0cVToztLYIMJnhjiSUs8nk83m/9/O4SGqQmievoZ5N
60OlhU6enfFoj1xKpXWSGv6mqqdX0G9Ehz1EIetFhkBK2pP/R00gf4OMKc4ubw8d
yTSUIeMSOo0QjA==
-----END CERTIFICATE-----'''
    .codeUnits;

final SecurityContext serverSecurityContext = () {
  final context = SecurityContext();
  context.usePrivateKeyBytes(key);
  context.useCertificateChainBytes(cert);
  return context;
}();

Future<Uint8List> loadCertificateBytes(String path) async {
  return (await rootBundle.load(path)).buffer.asUint8List();
}

Future<SecurityContext> serverContext(String certType, String password) async =>
    SecurityContext()
      ..useCertificateChainBytes(
          await loadCertificateBytes('certificates/server_chain.p12'),
          password: password)
      ..usePrivateKeyBytes(
          await loadCertificateBytes('certificates/server_key.p12'),
          password: password)
      ..setTrustedCertificatesBytes(
          await loadCertificateBytes('certificates/test-combined.p12'),

//        await loadCertificateBytes('test_certs/client-cert.p12'),
          password: '1234');

Future<void> runServer() async {
  // https://github.com/dart-lang/sdk/issues/52609
  final server = await SecureServerSocket.bind(
      'localhost', 8080, await serverContext('p12', 'dartdart'),
      requestClientCertificate: true, requireClientCertificate: true);
  print('ok ${server.port}');
  server.listen((socket) async {
    print('Peer: ${socket.peerCertificate}');
    socket.writeAll(['HTTP/1.1 200 OK', 'Content-Length: 0', '\r\n'], '\r\n');
    print('server: got connection');

    await socket.close();
  });
}

Future<Client> okHttpClient() async {
  final clientCert = // await loadCertificateBytes('test_certs/client-cert.p12');
      await loadCertificateBytes('certificates/test-combined.p12');
  return OkHttpClient(Uint8List(0), clientCert);
}

Future<Client> ioClient() async {
  final context = SecurityContext()
    ..usePrivateKeyBytes(
        await loadCertificateBytes('certificates/test-combined.p12'),
        password: '1234');
  return IOClient(
      HttpClient(context: context)..badCertificateCallback = (x, y, z) => true);
}

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

//  final clientCert =
//      await loadCertificateBytes('certificates/test-combined.p12');

  test('test', () async {
    await runServer();
    final httpClient = await okHttpClient();

    await httpClient.get(Uri.https('localhost:8080', '/'));
  });
}
