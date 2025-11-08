// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http;
import 'package:http_multi_server/http_multi_server.dart';
import 'package:http_multi_server/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('with multiple HttpServers', () {
    late HttpMultiServer multiServer;
    late HttpServer subServer1;
    late HttpServer subServer2;
    late HttpServer subServer3;

    setUp(() => Future.wait([
          HttpServer.bind('localhost', 0).then((server) => subServer1 = server),
          HttpServer.bind('localhost', 0).then((server) => subServer2 = server),
          HttpServer.bind('localhost', 0).then((server) => subServer3 = server)
        ]).then((servers) => multiServer = HttpMultiServer(servers)));

    tearDown(() => multiServer.close());

    test('listen listens to all servers', () {
      multiServer.listen((request) {
        request.response.write('got request');
        request.response.close();
      });

      expect(_read(subServer1), completion(equals('got request')));
      expect(_read(subServer2), completion(equals('got request')));
      expect(_read(subServer3), completion(equals('got request')));
    });

    test('serverHeader= sets the value for all servers', () {
      multiServer
        ..serverHeader = 'http_multi_server test'
        ..listen((request) {
          request.response.write('got request');
          request.response.close();
        });

      expect(
          _get(subServer1).then((response) {
            expect(
                response.headers['server'], equals('http_multi_server test'));
          }),
          completes);

      expect(
          _get(subServer2).then((response) {
            expect(
                response.headers['server'], equals('http_multi_server test'));
          }),
          completes);

      expect(
          _get(subServer3).then((response) {
            expect(
                response.headers['server'], equals('http_multi_server test'));
          }),
          completes);
    });

    test('autoCompress= sets the value for all servers', () {
      multiServer
        ..autoCompress = true
        ..listen((request) {
          request.response.write('got request');
          request.response.close();
        });

      expect(
          _get(subServer1).then((response) {
            expect(response.headers['content-encoding'], equals('gzip'));
          }),
          completes);

      expect(
          _get(subServer2).then((response) {
            expect(response.headers['content-encoding'], equals('gzip'));
          }),
          completes);

      expect(
          _get(subServer3).then((response) {
            expect(response.headers['content-encoding'], equals('gzip'));
          }),
          completes);
    });

    test('headers.set sets the value for all servers', () {
      multiServer.defaultResponseHeaders
          .set('server', 'http_multi_server test');

      multiServer.listen((request) {
        request.response.write('got request');
        request.response.close();
      });

      expect(
          _get(subServer1).then((response) {
            expect(
                response.headers['server'], equals('http_multi_server test'));
          }),
          completes);

      expect(
          _get(subServer2).then((response) {
            expect(
                response.headers['server'], equals('http_multi_server test'));
          }),
          completes);

      expect(
          _get(subServer3).then((response) {
            expect(
                response.headers['server'], equals('http_multi_server test'));
          }),
          completes);
    });

    test('connectionsInfo sums the values for all servers', () {
      var pendingRequests = 0;
      final awaitingResponseCompleter = Completer<void>();
      final sendResponseCompleter = Completer<void>();
      multiServer.listen((request) {
        sendResponseCompleter.future.then((_) {
          request.response.write('got request');
          request.response.close();
        });

        pendingRequests++;
        if (pendingRequests == 2) awaitingResponseCompleter.complete();
      });

      // Queue up some requests, then wait on [awaitingResponseCompleter] to
      // make sure they're in-flight before we check [connectionsInfo].
      expect(_get(subServer1), completes);
      expect(_get(subServer2), completes);

      return awaitingResponseCompleter.future.then((_) {
        final info = multiServer.connectionsInfo();
        expect(info.total, equals(2));
        expect(info.active, equals(2));
        expect(info.idle, equals(0));
        expect(info.closing, equals(0));

        sendResponseCompleter.complete();
      });
    });
  });

  group('HttpMultiServer.loopback', () {
    late HttpServer server;

    setUp(() => HttpMultiServer.loopback(0).then((s) => server = s));

    tearDown(() => server.close());

    test('listens on all localhost interfaces', () async {
      server.listen((request) {
        request.response.write('got request');
        request.response.close();
      });

      if (await supportsIPv4) {
        expect(http.read(Uri.http('127.0.0.1:${server.port}', '/')),
            completion(equals('got request')));
      }

      if (await supportsIPv6) {
        expect(http.read(Uri.http('[::1]:${server.port}', '/')),
            completion(equals('got request')));
      }
    });
  });

  group('HttpMultiServer.bind', () {
    test("listens on all localhost interfaces for 'localhost'", () async {
      final server = await HttpMultiServer.bind('localhost', 0);
      server.listen((request) {
        request.response.write('got request');
        request.response.close();
      });

      if (await supportsIPv4) {
        expect(http.read(Uri.http('127.0.0.1:${server.port}', '/')),
            completion(equals('got request')));
      }

      if (await supportsIPv6) {
        expect(http.read(Uri.http('[::1]:${server.port}', '/')),
            completion(equals('got request')));
      }
    });

    test("listens on all localhost interfaces for 'any'", () async {
      final server = await HttpMultiServer.bind('any', 0);
      server.listen((request) {
        request.response.write('got request');
        request.response.close();
      });

      if (await supportsIPv4) {
        expect(http.read(Uri.http('127.0.0.1:${server.port}', '/')),
            completion(equals('got request')));
      }

      if (await supportsIPv6) {
        expect(http.read(Uri.http('[::1]:${server.port}', '/')),
            completion(equals('got request')));
      }
    });

    test("uses the correct server address for 'any'", () async {
      final server = await HttpMultiServer.bind('any', 0);

      if (!await supportsIPv6) {
        expect(server.address, InternetAddress.anyIPv4);
      } else {
        expect(server.address, InternetAddress.anyIPv6);
      }
    });

    test('listens on specified hostname', () async {
      if (!await supportsIPv4) return;
      final server = await HttpMultiServer.bind(InternetAddress.anyIPv4, 0);
      server.listen((request) {
        request.response.write('got request');
        request.response.close();
      });

      expect(http.read(Uri.http('127.0.0.1:${server.port}', '/')),
          completion(equals('got request')));

      if (await supportsIPv6) {
        expect(http.read(Uri.http('[::1]:${server.port}', '/')),
            throwsA(isA<SocketException>()));
      }
    });
  });

  group('HttpMultiServer.bindSecure', () {
    late http.Client client;
    late SecurityContext context;
    setUp(() async {
      context = SecurityContext()
        ..setTrustedCertificatesBytes(_sslCert)
        ..useCertificateChainBytes(_sslCert)
        ..usePrivateKeyBytes(_sslKey, password: 'dartdart');
      client = http.IOClient(HttpClient(context: context));
    });
    test('listens on all localhost interfaces for "localhost"', () async {
      final server = await HttpMultiServer.bindSecure('localhost', 0, context);
      server.listen((request) {
        request.response.write('got request');
        request.response.close();
      });

      if (await supportsIPv4) {
        expect(client.read(Uri.https('127.0.0.1:${server.port}')),
            completion(equals('got request')));
      }

      if (await supportsIPv6) {
        expect(client.read(Uri.https('[::1]:${server.port}')),
            completion(equals('got request')));
      }
    });

    test('listens on all localhost interfaces for "any"', () async {
      final server = await HttpMultiServer.bindSecure('any', 0, context);
      server.listen((request) {
        request.response.write('got request');
        request.response.close();
      });

      if (await supportsIPv4) {
        expect(client.read(Uri.https('127.0.0.1:${server.port}')),
            completion(equals('got request')));
      }

      if (await supportsIPv6) {
        expect(client.read(Uri.https('[::1]:${server.port}')),
            completion(equals('got request')));
      }
    });

    test('listens on specified hostname', () async {
      if (!await supportsIPv4) return;
      final server =
          await HttpMultiServer.bindSecure(InternetAddress.anyIPv4, 0, context);
      server.listen((request) {
        request.response.write('got request');
        request.response.close();
      });

      expect(client.read(Uri.https('127.0.0.1:${server.port}')),
          completion(equals('got request')));

      if (await supportsIPv6) {
        expect(client.read(Uri.https('[::1]:${server.port}')),
            throwsA(isA<SocketException>()));
      }
    });
  });
}

/// Makes a GET request to the root of [server] and returns the response.
Future<http.Response> _get(HttpServer server) => http.get(_urlFor(server));

/// Makes a GET request to the root of [server] and returns the response body.
Future<String> _read(HttpServer server) => http.read(_urlFor(server));

/// Returns the URL for the root of [server].
Uri _urlFor(HttpServer server) =>
    Uri.http('${server.address.host}:${server.port}', '/');

// The certificates were taken from the Dart SDK at
// `_sslCert`: tests/standalone/io/certificates/untrusted_server_chain.pem
// `_sslKey`: tests/standalone/io/certificates/untrusted_server_key.pem
//
// I tried to recreate these certificates using a modified version of the script
// at tests/standalone/io/create_sample_certificates.sh but the
// "PBE-SHA1-RC4-128" algorithm is no longer supported by openssl and replacing
// it with "aes-256-cbc" causes the tests to fail with:
//
// HandshakeException: Handshake error in client (OS Error:
// CERTIFICATE_VERIFY_FAILED:
//                       ... application verification failure(handshake.cc:297))
//
// The current certificates will expire in 2030.
final _sslCert = utf8.encode('''
-----BEGIN CERTIFICATE-----
MIIDZDCCAkygAwIBAgIBATANBgkqhkiG9w0BAQsFADAgMR4wHAYDVQQDDBVpbnRl
cm1lZGlhdGVhdXRob3JpdHkwHhcNMTgwNDIzMTcxNTEzWhcNMjgwNDIwMTcxNTEz
WjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
ggEKAoIBAQDO+XxT1pAvzkIWvAZJFGEjuIuXz1kNoCDxBHAilptAOCX5sKyLaWTc
YvzYpDf0LOwU3T/ZtlSinkX2xCY7EXgsGJEFc1RDmhmPmSsY9Az/ewS1TNrTOkD5
VGUwnRKpl3o+140A/aNYGQfHJRz0+BCLftv7b95HinLDq26d01eTHLOozfGqkcfA
LfUauiwXRV817ceLiliGUtgW8DDNTVqtHA2aeKVisZZtyeEMc3BsnJDGmU6kcQ4B
KeLHaaxCufy4bMlObwSLcdlp7R6MTudzKVEjXVz/WRLz7yZYaYDrcacUvsI8v+jX
B7quGGkLGJH+GxDGMObFWKsAB229c9ZlAgMBAAGjgbQwgbEwPAYDVR0RBDUwM4IJ
bG9jYWxob3N0ggkxMjcuMC4wLjGCAzo6MYcEfwAAAYcQAAAAAAAAAAAAAAAAAAAA
ATAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBR6zQbX0GnDCsjksKYXlzovO2yplDAf
BgNVHSMEGDAWgBSkX16pB/ZB0hzdYIUgMhWO89CxZzAOBgNVHQ8BAf8EBAMCA6gw
EwYDVR0lBAwwCgYIKwYBBQUHAwEwDQYJKoZIhvcNAQELBQADggEBAIDPqZllHvJa
XSpqOFaT7oFzKbBnV8lLMvYnbDWHL8N+23q+y803GGNRMkDJG98OalqqKMskk4/v
ek6dhkTHKnB7hunhogIICXCcHOJGaHN67vvkxkP5mTx6AMaPT+q6NXzu2y9YBTkr
BIw6ZUyPxqIcH4/GezVe+pokvNZHghDePBChALXEmQLBuJy+gM55w4nB5eq8pNnP
1r9vVhlr4jqiVNd95MglwB4xLQV5SeG8gGwGvad0vvIpHljOwT9TmlofeqqGpPLf
3LtqrBK5qdxWcn0jDxG/Qe2EfsdmzsCQ+imu5rTc1YMCGZD52mnnq4tZj0hroWLn
Wys+JpPMdKo=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIDLjCCAhagAwIBAgIBAjANBgkqhkiG9w0BAQsFADAYMRYwFAYDVQQDDA1yb290
YXV0aG9yaXR5MB4XDTE4MDQyMzE3MTUxMloXDTI4MDQyMDE3MTUxMlowIDEeMBwG
A1UEAwwVaW50ZXJtZWRpYXRlYXV0aG9yaXR5MIIBIjANBgkqhkiG9w0BAQEFAAOC
AQ8AMIIBCgKCAQEAvpFatw9XMWQDbKzWtsA5NfjQsddw5wlDpFeRYghyqo/mgWru
Rapcz6tEpEodc3SZ/4PCwE1PmYZuxhcYnaDCM3YdmJAMPUhqi+YO+Gc7WNTbrOR0
aJGzS2HEPxjbC4OsFG7TVuKMH1uI4rWOZxBn4rODkTmiH7epuyu65nzUJemct8GV
OcPChjPVKvXzbHVtk8UVreD/DVyuYwsBMSAuYWiq2pgAAQV/7TKVDAQ8yRVW28J7
+QrNXqV+I6MZeMho45xgLNQmi5os9vqTuEu3oGyLFWxXz6uJ2MOFOFTjxMhHGcGn
aICAA9BIcCeaWWRN9nZkvQuS2nysvJwBu/LROQIDAQABo3sweTASBgNVHRMBAf8E
CDAGAQH/AgEAMB0GA1UdDgQWBBSkX16pB/ZB0hzdYIUgMhWO89CxZzAfBgNVHSME
GDAWgBR9W+i1d5oZtiZAEjI9RDLd9SnUnDAOBgNVHQ8BAf8EBAMCAgQwEwYDVR0l
BAwwCgYIKwYBBQUHAwEwDQYJKoZIhvcNAQELBQADggEBAIdIh5sIk9Qi2KZfzJUQ
/DmMTv6NZzAGROJGA+o6jfrMh/plzBre7QM2vzw6iHxFokepLnsXtgrqdtr1lluO
R6apN2QLp5AJeT8gZfn0V35Wz2iYn+fJR77Map3u57IOj08gvk/BZmJxxqMT/qH/
1H5qpd934aFLSgqsmpGOVIzrdwHVmwOKU9SDNxOILVpvgtjQ/KWEUxftKtU7Z/dd
WGN56Vu3Ul0gzgCFifj8mnHnHpug/wEHLl0l2hk3BD1AUrCyCK4yalvsDV7vFex7
8+Whuh4OijTP/yomn8VGPN5lMmGT4XN8Z3h97PUHF9yF4FYGJJ/lilIhxctashk+
HuE=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIC/jCCAeagAwIBAgIBATANBgkqhkiG9w0BAQsFADAYMRYwFAYDVQQDDA1yb290
YXV0aG9yaXR5MB4XDTE4MDQyMzE3MTUxMloXDTI4MDQyMDE3MTUxMlowGDEWMBQG
A1UEAwwNcm9vdGF1dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
ggEBAMuTL5lztughNg/G/9Ge8c6EmROymW0zGTN6hRp3rG2SkpJdag08ntKAmny3
ilpnlEoxGOk1L9jq/lJsCsiqsSETCadkLsXFNeKOG+S48nc8ThOrmJe5WV6NDNmn
qaQeek5rjvuRSdukhyZVLzmIyTYNErwkMuo+Jk1V7IS1X2pFyTfF+SLlYrOuDQIW
qXYfWqdMSYpI8s3onIwR/qVapGu55D0CECzNyX6ZBnqYK0cGzmRaZToT84VPsJwB
DmALQw9WNNn1CHAIt17CwsdSSasgaKz/XDDjwgKL7CI6bFttDIWVLBt8ikrsrjZN
6L5b8PZx/dHwJJ7QjYOMKKSUjyECAwEAAaNTMFEwHQYDVR0OBBYEFH1b6LV3mhm2
JkASMj1EMt31KdScMB8GA1UdIwQYMBaAFH1b6LV3mhm2JkASMj1EMt31KdScMA8G
A1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAJTJx9nh+fTJ6a0aIzPY
FUX5tg+MdUxsAG5QA2jrwZIKCSrHa/ka0vjwLO+94EWcWgKdNDu8lt2FPnJh0nzN
Ad/CaQNSMesihlmGOgxvLgd3ndYDVYjsCrXx3ESoRavgAWXY+/p69KR1ibVLpKF/
yr/YURqT9SLKAlgrZt5I/syzxhWdAND62oxqiDCMzPoVR2cLswIUDNRvq5nRiCIt
1TLPDINjG1EdmwzV2jyPxphL8esopopVm/d9wgD0xQ2Ocb2Nj6Jduuli0sm+dVBL
3t2pldRq0hXZt/9qhu38tF41TlKSpCz2oFyx2D6ObLSX0MeFp6zXM0c1lGqSCDIM
ubk=
-----END CERTIFICATE-----
''');

List<int> _sslKey = utf8.encode('''
-----BEGIN ENCRYPTED PRIVATE KEY-----
MIIE5TAcBgoqhkiG9w0BDAEBMA4ECI8YmURjepD4AgIIAASCBMMwp7gfo4FvSVuR
5w7+OcjkXNQmvrwTRFDaMWV3ORgVFMQx02Q325SnoQsmulB+dk19uj2Piel5j/+j
xHLvC0rBQC8BjHg/uLmN/f9yW6qolDthmeJEad/L8slB7rziilOGmlPh7H1voJgr
94uoTn6L2tE9GfoPDsksedRtGIlgSOM3UmLvCkCMcZBqrDi4uqzbhrW3bIbqdoeo
1lbNsvFuNzF+P3cBHyUUZpPGwCZ8M/XCsCAB+9eH7TM2FJnbuffA6BfkanpQR0ul
PLo5KDjcS5lQ4YUkI2+lYMSZMiIf50Y8eHP0QnDAuYunA2cPLd90rPpdBCgNtQqk
aUI7FHvtLFZsTJ1s8EPnZhZOZq1LYUTFQuimMWz+nvC0oQy925brwyjfnrm44KS7
xpJqsYMBHYflDCwE4LbxjFSeneOy4wwNMurupSdcLCm02Sm1wUMrzRrNsAy3jxP6
TfJjHRBSt3XEDwDG3olQoK/Ewa1qP0JhAZOd7SrKw9eLQltH+djy0iDUblf5uIHj
pDC+T1pY9tTwSVxhsJI5a0qxXYNgdaxhr0Fv8BbdScd8Tzdw7g4AByjvgCKArlNJ
alR1ZaJP/JYuzb3VH8uXEO4b6Tjqw9O4tkZGrc8He5HTAOnSZKbclDxyRH8hkDy+
apIJUjbE3Gc1mCbyo2nc6WDrGfQNrXDWAVIz4/lb8e8P5k1Rex4rVNhb/VA0Vh4m
T2BSQ3pvZtKTFedvWgIFIk85rVaYyuB7Icb0YLs2cPppMCfbv+6bOMkJ4hVk5tbX
AGk6FOjgqsQSY/gzDo9ReCJooETP2AmvHEi2b7LKs+M0Pw+CfvKD/dOkQp62WMpt
vZJVSXIQ2bHarbhxmUxcT//G+i3QBgkM2xTRvARfRMBiCoBh0Ta3gd4/GJDwv8pr
pkJi3Q6u88NfGG0eyYyHz+kqTtptqJj1hbAFPdt6d6sFL/wpwhK/L5MOECQ3m100
N3/aGT7yizM0w/m6PSycSbXycRafRF3XNMBXsUWeFpSWxpJV9GH+T3z8k46GrsM6
c3YrLG6nvmersDI2AuS9KuhIQQvp+sgwjt3HeURsDv3X4edgCILRTjv3nVuU+DGD
Xd8CuPYmRei4eJ4nkzxY6fM7ticuArnyE+INVtA0T8yL4UbRxQV/f9jOZWJ1LXLr
caxCOZP9YcDVG9JUK4WGUC3LVWfhJW+i51cLJk9iGZ8qDLSvgJhj+/7Ajsg6/4xO
IPon0DVMD9jgMSWLdfpCPawyY+VLVH2CXB2z83c2818gAs85QGUlsW+xLkELSTIU
6p+mtTF5B2IhsjEdMDAWOpAp/Gj/U9OKapTyE1sGxn66jG/UvxcgYqZo3JGjNaDE
rMnBhOH4VQQ+FxCA6lXKYCcU1UEze5BuCzJCA7gmCceMlMe+1Car2F+nJCuLNtzB
uJhlXDbIVhMb5cZBBd3LSjmuRZ/gWbMvV3UqoCROBXqLzVGTufpcn/MgYQKYYHkp
I+vKDypj0a4IPovDdxg8aMKNn59mtvmMDyrt0716H9DP4SCU/nuxVSeT/HywRBo/
53fxqtdH3hTAUXqcOLzHnvLUENiABKMeJOtGTV9MFCxgGsnzgYNXnB9hDhm84+IX
JQdMjj+BNFE6
-----END ENCRYPTED PRIVATE KEY-----
''');
