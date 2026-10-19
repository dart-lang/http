// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http;
import 'package:http_multi_server/http_multi_server.dart';
import 'package:http_multi_server/src/utils.dart';
import 'package:test/test.dart';

import 'cert.dart' show sslCert, sslKey;

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
    test('listens on all localhost interfaces', () async {
      final server = await HttpMultiServer.loopback(0);
      addTearDown(server.close);
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

    test('retries when the ephemeral IPv4 port is already bound on IPv6',
        () async {
      if (!await supportsIPv4 || !await supportsIPv6) return;

      final busyV6 = await HttpServer.bind(InternetAddress.loopbackIPv6, 0);
      addTearDown(busyV6.close);

      final server = await IOOverrides.runWithIOOverrides(
        () => HttpMultiServer.loopback(0),
        _FirstV4PortOverride(busyV6.port),
      );
      addTearDown(server.close);

      expect(server.port, isNot(0));
      expect(server.port, isNot(busyV6.port));
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
        ..setTrustedCertificatesBytes(sslCert)
        ..useCertificateChainBytes(sslCert)
        ..usePrivateKeyBytes(sslKey, password: 'dartdart');
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

final class _FirstV4PortOverride extends IOOverrides {
  _FirstV4PortOverride(this._firstPort);

  final int _firstPort;
  var _firstV4Bind = true;

  @override
  Future<ServerSocket> serverSocketBind(
    dynamic address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
  }) {
    if (_firstV4Bind && address == InternetAddress.loopbackIPv4 && port == 0) {
      _firstV4Bind = false;
      port = _firstPort;
    }
    return super.serverSocketBind(
      address,
      port,
      backlog: backlog,
      v6Only: v6Only,
      shared: shared,
    );
  }
}
