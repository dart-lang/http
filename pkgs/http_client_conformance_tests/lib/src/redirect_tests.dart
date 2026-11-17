// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'redirect_server_vm.dart'
    if (dart.library.js_interop) 'redirect_server_web.dart';

/// Tests that the [Client] correctly implements HTTP redirect logic.
///
/// If [canSendCookieHeaders] is `false` then tests that require that "cookie"
/// headers be sent by the client will not be run.
///
/// If [canSendProxyAuthorizationHeaders] is `false` then tests that require
/// that "proxy-authorization" headers be set by the client will not be run.
///
/// If [canSetUserInfo] is `false` then tests that require that the request URL
/// contain userinfo (e.g. `http://user:password@example.com/`) will not be
/// run.
///
/// If [correctCrossHostRedirect] is `false` then tests that verify the behavior
/// of relative redirects and of redirects across host/port boundaries will be
/// skipped.
///
/// If [redirectAlwaysAllowed] is `true` then tests that require the [Client]
/// to limit redirects will be skipped.
void testRedirect(Client Function() clientFactory,
    {bool canSendCookieHeaders = true,
    bool canSendProxyAuthorizationHeaders = true,
    bool canSetUserInfo = true,
    bool correctCrossHostRedirect = false,
    bool redirectAlwaysAllowed = false}) {
  group('redirects', () {
    // RFC 9110, 15.4 says:
    // Consider removing header fields that were not automatically generated
    // by the implementation...where there are security implications; this
    // includes but is not limited to Authorization and Cookie.
    //
    // RFC 6265, 8.5 says:
    // Cookies do not provide isolation by port. If a cookie is readable by a
    // service running on one port, the cookie is also readable by a service
    // running on another port of the same server.
    //
    // So the behavior that we test is:
    // - if a redirect changes hosts (e.g., localhost -> 127.0.0.1) then it
    //   MUST drop headers with security implications.
    // - if a redirect changes ports then it MUST drop headers with security
    //   implications, except for cookies which MAY be dropped
    // - headers with no security implications MUST NOT be dropped during
    //   redirect

    late Client client;
    late String localhost1;
    late String localhost2;
    late String loopback1;
    late String loopback2;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      final port1 = await httpServerQueue.nextAsInt;
      final port2 = await httpServerQueue.nextAsInt;
      localhost1 = 'localhost:$port1';
      localhost2 = 'localhost:$port2';
      loopback1 = '127.0.0.1:$port1';
      loopback2 = '127.0.0.1:$port2';
      client = clientFactory();
    });
    tearDown(() {
      client.close();
      httpServerChannel.sink.add(null);
    });

    test('no redirect', () async {
      final request = Request('GET', Uri.http(localhost1, '/'))
        ..followRedirects = false;
      final response = await client.send(request);
      await response.stream.drain<void>();
      expect(response.statusCode, 200);
      expect(response.isRedirect, false);
      if (response case BaseResponseWithUrl(url: final url)) {
        expect(url, Uri.http(localhost1, '/'));
      }
    });

    test('disallow redirect', () async {
      final request = Request('GET', Uri.http(localhost1, '/1'))
        ..followRedirects = false;
      final response = await client.send(request);
      await response.stream.drain<void>();
      expect(response.statusCode, 302);
      expect(response.isRedirect, true);
      if (response case BaseResponseWithUrl(url: final url)) {
        expect(url, Uri.http(localhost1, '/1'));
      }
    }, skip: redirectAlwaysAllowed ? 'redirects always allowed' : false);

    test('disallow redirect, 0 maxRedirects', () async {
      final request = Request('GET', Uri.http(localhost1, '/1'))
        ..followRedirects = false
        ..maxRedirects = 0;
      final response = await client.send(request);
      await response.stream.drain<void>();
      expect(response.statusCode, 302);
      expect(response.isRedirect, true);
      if (response case BaseResponseWithUrl(url: final url)) {
        expect(url, Uri.http(localhost1, '/1'));
      }
    }, skip: redirectAlwaysAllowed ? 'redirects always allowed' : false);

    test('allow redirect', () async {
      final request = Request('GET', Uri.http(localhost1, '/1'))
        ..followRedirects = true;
      request.headers['hello'] = 'world';
      if (canSendCookieHeaders) {
        request.headers['cookie'] = 'foo=bar';
      }
      final response = await client.send(request);
      await response.stream.drain<void>();
      expect(response.statusCode, 200);
      expect(response.isRedirect, false);
      if (response case BaseResponseWithUrl(url: final url)) {
        expect(url, Uri.http(localhost1, '/'));
      }
      final [server1, method1, body1, headers1] =
          await httpServerQueue.next as List<Object?>;
      expect(server1, 'server1');
      expect(method1, 'GET');
      expect(body1, isEmpty);
      expect(headers1, containsPair('host', [localhost1]));
      expect(headers1, containsPair('hello', ['world']));
      if (canSendCookieHeaders) {
        expect(headers1, containsPair('cookie', ['foo=bar']));
      }
      final [server2, method2, body2, headers2] =
          await httpServerQueue.next as List<Object?>;
      expect(server2, 'server1');
      expect(method2, 'GET');
      expect(body2, isEmpty);
      expect(headers2, containsPair('host', [localhost1]));
      expect(headers2, containsPair('hello', ['world']));
      if (canSendCookieHeaders) {
        expect(headers2, containsPair('cookie', ['foo=bar']));
      }
    });

    test('relative redirect', () async {
      final request = Request('GET', Uri.http(localhost1, '/relative'))
        ..followRedirects = true;
      request.headers['hello'] = 'world';
      if (canSendCookieHeaders) {
        request.headers['cookie'] = 'foo=bar';
      }
      final response = await client.send(request);
      await response.stream.drain<void>();
      expect(response.statusCode, 200);
      expect(response.isRedirect, false);
      if (response case BaseResponseWithUrl(url: final url)) {
        expect(url, Uri.http(localhost1, '/'));
      }
      final [server1, method1, body1, headers1] =
          await httpServerQueue.next as List<Object?>;
      expect(server1, 'server1');
      expect(method1, 'GET');
      expect(body1, isEmpty);
      expect(headers1, containsPair('host', [localhost1]));
      expect(headers1, containsPair('hello', ['world']));
      if (canSendCookieHeaders) {
        expect(headers1, containsPair('cookie', ['foo=bar']));
      }
      final [server2, method2, body2, headers2] =
          await httpServerQueue.next as List<Object?>;
      expect(server2, 'server1');
      expect(method2, 'GET');
      expect(body2, isEmpty);
      expect(headers2, containsPair('host', [localhost1]));
      expect(headers2, containsPair('hello', ['world']));
      if (canSendCookieHeaders) {
        expect(headers2, containsPair('cookie', ['foo=bar']));
      }
    },
        skip: correctCrossHostRedirect
            ? false
            : 'not opted into relative redirect tests');

    test('allow redirect, 0 maxRedirects', () async {
      final request = Request('GET', Uri.http(localhost1, '/1'))
        ..followRedirects = true
        ..maxRedirects = 0;
      expect(
          client.send(request),
          throwsA(isA<ClientException>()
              .having((e) => e.message, 'message', 'Redirect limit exceeded')));
    }, skip: redirectAlwaysAllowed ? 'redirects always allowed' : false);

    test('exactly the right number of allowed redirects', () async {
      final request = Request('GET', Uri.http(localhost1, '/5'))
        ..followRedirects = true
        ..maxRedirects = 5;
      final response = await client.send(request);
      await response.stream.drain<void>();
      expect(response.statusCode, 200);
      expect(response.isRedirect, false);
      if (response case BaseResponseWithUrl(url: final url)) {
        expect(url, Uri.http(localhost1, '/'));
      }
    }, skip: redirectAlwaysAllowed ? 'redirects always allowed' : false);

    test('too many redirects', () async {
      final request = Request('GET', Uri.http(localhost1, '/6'))
        ..followRedirects = true
        ..maxRedirects = 5;
      expect(
          client.send(request),
          throwsA(isA<ClientException>()
              .having((e) => e.message, 'message', 'Redirect limit exceeded')));
    }, skip: redirectAlwaysAllowed ? 'redirects always allowed' : false);

    test(
      'loop',
      () async {
        final request = Request('GET', Uri.http(localhost1, '/loop'))
          ..followRedirects = true
          ..maxRedirects = 5;
        expect(client.send(request), throwsA(isA<ClientException>()));
      },
    );

    group('cross origin', () {
      for (final (authorization, cookie, proxyAuthorization) in [
        ('authorization', 'cookie', 'proxy-authorization'),
        ('Authorization', 'Cookie', 'Proxy-Authorization'),
        ('AUTHORIZATION', 'COOKIE', 'PROXY-AUTHORIZATION'),
      ]) {
        test(
            'cross port redirect '
            '($authorization, $cookie, $proxyAuthorization)', () async {
          final request = Request('GET', Uri.http(localhost1, '/cross-port'))
            ..followRedirects = true
            ..maxRedirects = 1;
          request.headers['hello'] = 'world';
          request.headers[authorization] = 'anything';
          if (canSendCookieHeaders) {
            request.headers[cookie] = 'foo=bar';
          }
          if (canSendProxyAuthorizationHeaders) {
            request.headers[proxyAuthorization] = 'anything';
          }

          final response = await client.send(request);
          await response.stream.drain<void>();
          expect(response.statusCode, 200);
          expect(response.isRedirect, false);
          if (response case BaseResponseWithUrl(url: final url)) {
            expect(url, Uri.http(localhost2, '/'));
          }

          final [server1, _, _, headers1] =
              await httpServerQueue.next as List<Object?>;
          expect(server1, 'server1');
          expect(headers1, containsPair('host', [localhost1]));
          expect(headers1, containsPair('hello', ['world']));
          expect(headers1, containsPair('authorization', ['anything']));
          if (canSendCookieHeaders) {
            expect(headers1, containsPair('cookie', ['foo=bar']));
          }
          if (canSendProxyAuthorizationHeaders) {
            expect(headers1, containsPair('proxy-authorization', ['anything']));
          }

          final [server2, _, _, headers2] =
              await httpServerQueue.next as List<Object?>;
          expect(server2, 'server2');
          expect(headers2, containsPair('host', [localhost2]));
          expect(headers2, containsPair('hello', ['world']));
          // Cookies may or may not be preserved.
          expect(headers2, isNot(contains('authorization')));
          expect(headers2, isNot(contains('proxy-authorization')));
        });

        test(
            'cross host redirect '
            '($authorization, $cookie, $proxyAuthorization)', () async {
          final request = Request('GET', Uri.http(localhost1, '/cross-host'))
            ..followRedirects = true
            ..maxRedirects = 1;
          request.headers['hello'] = 'world';
          request.headers[authorization] = 'anything';
          if (canSendCookieHeaders) {
            request.headers[cookie] = 'foo=bar';
          }
          if (canSendProxyAuthorizationHeaders) {
            request.headers[proxyAuthorization] = 'anything';
          }
          final response = await client.send(request);
          await response.stream.drain<void>();
          expect(response.statusCode, 200);
          expect(response.isRedirect, false);

          final [server1, _, _, headers1] =
              await httpServerQueue.next as List<Object?>;
          expect(server1, 'server1');
          expect(headers1, containsPair('host', [localhost1]));
          expect(headers1, containsPair('hello', ['world']));
          expect(headers1, containsPair('authorization', ['anything']));
          if (canSendCookieHeaders) {
            expect(headers1, containsPair('cookie', ['foo=bar']));
          }
          if (canSendProxyAuthorizationHeaders) {
            expect(headers1, containsPair('proxy-authorization', ['anything']));
          }

          final [server2, _, _, headers2] =
              await httpServerQueue.next as List<Object?>;
          expect(server2, 'server1');
          expect(headers2, containsPair('host', [loopback1]));
          expect(headers2, containsPair('hello', ['world']));
          expect(headers2, isNot(contains('authorization')));
          expect(headers2, isNot(contains('cookie')));
          expect(headers2, isNot(contains('proxy-authorization')));
        });

        test(
            'cross host and back '
            '($authorization, $cookie, $proxyAuthorization)', () async {
          final request = Request('GET', Uri.http(localhost1, '/cross-ping'))
            ..followRedirects = true
            ..maxRedirects = 2;
          request.headers['hello'] = 'world';
          request.headers[authorization] = 'anything';
          if (canSendCookieHeaders) {
            request.headers[cookie] = 'foo=bar';
          }
          if (canSendProxyAuthorizationHeaders) {
            request.headers[proxyAuthorization] = 'anything';
          }
          final response = await client.send(request);
          await response.stream.drain<void>();
          expect(response.statusCode, 200);
          expect(response.isRedirect, false);
          if (response case BaseResponseWithUrl(url: final url)) {
            expect(url, Uri.http(localhost1, '/'));
          }

          final [server1, _, _, headers1] =
              await httpServerQueue.next as List<Object?>;
          expect(server1, 'server1');
          expect(headers1, containsPair('host', [localhost1]));
          expect(headers1, containsPair('hello', ['world']));
          expect(headers1, containsPair('authorization', ['anything']));
          if (canSendCookieHeaders) {
            expect(headers1, containsPair('cookie', ['foo=bar']));
          }
          if (canSendProxyAuthorizationHeaders) {
            expect(headers1, containsPair('proxy-authorization', ['anything']));
          }

          final [server2, _, _, headers2] =
              await httpServerQueue.next as List<Object?>;
          expect(server2, 'server2');
          expect(headers2, containsPair('host', [loopback2]));
          expect(headers2, containsPair('hello', ['world']));
          expect(headers2, isNot(contains('authorization')));
          expect(headers2, isNot(contains('cookie')));
          expect(headers2, isNot(contains('proxy-authorization')));

          final [server3, _, _, headers3] =
              await httpServerQueue.next as List<Object?>;
          expect(server3, 'server1');
          expect(headers3, containsPair('host', [localhost1]));
          expect(headers3, containsPair('hello', ['world']));
          expect(headers3, isNot(contains('authorization')));
          expect(headers3, isNot(contains('cookie')));
          expect(headers3, isNot(contains('proxy-authorization')));
        });
      }

      test('cross host and back with set-cookie', () async {
        // Each redirect response sets a cookie. A cookie set by one host must
        // not be sent to the other host.
        final request = Request('GET', Uri.http(localhost1, '/cookie-ping'))
          ..followRedirects = true
          ..maxRedirects = 2;
        final response = await client.send(request);
        await response.stream.drain<void>();
        expect(response.statusCode, 200);
        expect(response.isRedirect, false);
        if (response case BaseResponseWithUrl(url: final url)) {
          expect(url, Uri.http(localhost1, '/'));
        }

        final [server1, _, _, headers1] =
            await httpServerQueue.next as List<Object?>;
        expect(server1, 'server1');
        expect(headers1, containsPair('host', [localhost1]));

        final [server2, _, _, headers2] =
            await httpServerQueue.next as List<Object?>;
        expect(server2, 'server2');
        expect(headers2, containsPair('host', [loopback2]));
        expect(
            headers2,
            isNot(containsPair(
                'cookie', contains(contains('localhost-cookie')))));

        // "localhost-cookie" may or may not be sent, depending on whether the
        // client stores cookies.
        final [server3, _, _, headers3] =
            await httpServerQueue.next as List<Object?>;
        expect(server3, 'server1');
        expect(headers3, containsPair('host', [localhost1]));
        expect(
            headers3,
            isNot(
                containsPair('cookie', contains(contains('loopback-cookie')))));
      });

      test('cross host redirect with userinfo', () async {
        // The client may use the userinfo in the URL to generate an
        // "authorization" header. If it does, that header must not be sent to
        // another host.
        final request = Request(
            'GET', Uri.parse('http://user:password@$localhost1/cross-host'))
          ..followRedirects = true
          ..maxRedirects = 1;
        final response = await client.send(request);
        await response.stream.drain<void>();
        expect(response.statusCode, 200);
        expect(response.isRedirect, false);
        if (response case BaseResponseWithUrl(url: final url)) {
          expect(url, Uri.http(loopback1, '/'));
        }

        final [server1, _, _, headers1] =
            await httpServerQueue.next as List<Object?>;
        expect(server1, 'server1');
        expect(headers1, containsPair('host', [localhost1]));

        final [server2, _, _, headers2] =
            await httpServerQueue.next as List<Object?>;
        expect(server2, 'server1');
        expect(headers2, containsPair('host', [loopback1]));
        expect(headers2, isNot(contains('authorization')));
      }, skip: canSetUserInfo ? null : 'cannot set userinfo');

      test('scheme-relative cross host redirect', () async {
        final request = Request('GET', Uri.http(localhost1, '/scheme-relative'))
          ..followRedirects = true
          ..maxRedirects = 1;
        request.headers['hello'] = 'world';
        request.headers['authorization'] = 'anything';
        if (canSendCookieHeaders) {
          request.headers['cookie'] = 'foo=bar';
        }
        if (canSendProxyAuthorizationHeaders) {
          request.headers['proxy-authorization'] = 'anything';
        }
        final response = await client.send(request);
        await response.stream.drain<void>();
        expect(response.statusCode, 200);
        expect(response.isRedirect, false);
        if (response case BaseResponseWithUrl(url: final url)) {
          expect(url, Uri.http(loopback1, '/'));
        }

        final [server1, _, _, headers1] =
            await httpServerQueue.next as List<Object?>;
        expect(server1, 'server1');
        expect(headers1, containsPair('host', [localhost1]));
        expect(headers1, containsPair('hello', ['world']));
        expect(headers1, containsPair('authorization', ['anything']));
        if (canSendCookieHeaders) {
          expect(headers1, containsPair('cookie', ['foo=bar']));
        }
        if (canSendProxyAuthorizationHeaders) {
          expect(headers1, containsPair('proxy-authorization', ['anything']));
        }

        final [server2, _, _, headers2] =
            await httpServerQueue.next as List<Object?>;
        expect(server2, 'server1');
        expect(headers2, containsPair('host', [loopback1]));
        expect(headers2, containsPair('hello', ['world']));
        expect(headers2, isNot(contains('authorization')));
        expect(headers2, isNot(contains('cookie')));
        expect(headers2, isNot(contains('proxy-authorization')));
      });

      for (final code in [301, 302, 303]) {
        test('POST $code cross host redirect', () async {
          final request =
              Request('POST', Uri.http(localhost1, '/cross-host-$code'))
                ..body = 'Hello World!'
                ..followRedirects = true
                ..maxRedirects = 1;
          request.headers['hello'] = 'world';
          request.headers['authorization'] = 'anything';
          if (canSendCookieHeaders) {
            request.headers['cookie'] = 'foo=bar';
          }
          if (canSendProxyAuthorizationHeaders) {
            request.headers['proxy-authorization'] = 'anything';
          }

          final response = await client.send(request);
          await response.stream.drain<void>();

          final [server1, method1, body1, headers1] =
              await httpServerQueue.next as List<Object?>;
          expect(server1, 'server1');
          expect(method1, 'POST');
          expect(body1, 'Hello World!');
          expect(headers1, containsPair('host', [localhost1]));
          expect(headers1, containsPair('hello', ['world']));
          expect(headers1, containsPair('authorization', ['anything']));
          if (canSendCookieHeaders) {
            expect(headers1, containsPair('cookie', ['foo=bar']));
          }
          if (canSendProxyAuthorizationHeaders) {
            expect(headers1, containsPair('proxy-authorization', ['anything']));
          }

          if (code == 303) {
            // RFC 9110, 15.4.4: 303 redirects POST to GET.
            expect(response.statusCode, 200);
          } else {
            // RFC 9110, 15.4.2-15.4.3:
            // The server SHOULD generate a Location header field in the
            // response containing a preferred URI reference for the new
            // permanent URI. The user agent MAY use the Location field value
            // for automatic redirection.
            // Note: For historical reasons, a user agent MAY change the request
            // method from POST to GET for the subsequent request.
            expect(response.statusCode, anyOf(200, code));
          }

          if (response.statusCode == 200) {
            expect(response.isRedirect, false);
            if (response case BaseResponseWithUrl(url: final url)) {
              expect(url, Uri.http(loopback2, '/'));
            }

            final [server2, method2, body2, headers2] =
                await httpServerQueue.next as List<Object?>;
            expect(server2, 'server2');
            expect(method2, 'GET');
            expect(body2, isEmpty);
            expect(headers2, containsPair('host', [loopback2]));
            expect(headers2, containsPair('hello', ['world']));
            expect(headers2, isNot(contains('authorization')));
            expect(headers2, isNot(contains('cookie')));
            expect(headers2, isNot(contains('proxy-authorization')));
          }
        });
      }

      for (final code in [307, 308]) {
        test('GET $code cross host redirect', () async {
          final request =
              Request('GET', Uri.http(localhost1, '/cross-host-$code'))
                ..followRedirects = true
                ..maxRedirects = 1;
          request.headers['hello'] = 'world';
          request.headers['authorization'] = 'anything';
          if (canSendCookieHeaders) {
            request.headers['cookie'] = 'foo=bar';
          }
          if (canSendProxyAuthorizationHeaders) {
            request.headers['proxy-authorization'] = 'anything';
          }

          final response = await client.send(request);
          await response.stream.drain<void>();
          expect(response.statusCode, 200);
          expect(response.isRedirect, false);
          if (response case BaseResponseWithUrl(url: final url)) {
            expect(url, Uri.http(loopback2, '/'));
          }

          final [server1, method1, body1, headers1] =
              await httpServerQueue.next as List<Object?>;
          expect(server1, 'server1');
          expect(method1, 'GET');
          expect(body1, isEmpty);
          expect(headers1, containsPair('host', [localhost1]));
          expect(headers1, containsPair('hello', ['world']));
          expect(headers1, containsPair('authorization', ['anything']));
          if (canSendCookieHeaders) {
            expect(headers1, containsPair('cookie', ['foo=bar']));
          }
          if (canSendProxyAuthorizationHeaders) {
            expect(headers1, containsPair('proxy-authorization', ['anything']));
          }

          final [server2, method2, body2, headers2] =
              await httpServerQueue.next as List<Object?>;
          expect(server2, 'server2');
          expect(method2, 'GET');
          expect(body2, isEmpty);
          expect(headers2, containsPair('host', [loopback2]));
          expect(headers2, containsPair('hello', ['world']));
          expect(headers2, isNot(contains('authorization')));
          expect(headers2, isNot(contains('cookie')));
          expect(headers2, isNot(contains('proxy-authorization')));
        });

        test('POST $code cross host redirect', () async {
          final request =
              Request('POST', Uri.http(localhost1, '/cross-host-$code'))
                ..body = 'Hello World!'
                ..followRedirects = true
                ..maxRedirects = 1;
          request.headers['hello'] = 'world';
          request.headers['authorization'] = 'anything';
          if (canSendCookieHeaders) {
            request.headers['cookie'] = 'foo=bar';
          }
          if (canSendProxyAuthorizationHeaders) {
            request.headers['proxy-authorization'] = 'anything';
          }

          final response = await client.send(request);
          await response.stream.drain<void>();

          final [server1, method1, body1, headers1] =
              await httpServerQueue.next as List<Object?>;
          expect(server1, 'server1');
          expect(method1, 'POST');
          expect(body1, 'Hello World!');
          expect(headers1, containsPair('host', [localhost1]));
          expect(headers1, containsPair('hello', ['world']));
          expect(headers1, containsPair('authorization', ['anything']));
          if (canSendCookieHeaders) {
            expect(headers1, containsPair('cookie', ['foo=bar']));
          }
          if (canSendProxyAuthorizationHeaders) {
            expect(headers1, containsPair('proxy-authorization', ['anything']));
          }

          // RFC 9110, 15.4.8-15.4.9:
          // The user agent MAY use the Location field value for automatic
          // redirection, and MUST NOT change the request method if it performs
          // an automatic redirection to that URI.
          expect(response.statusCode, anyOf(200, code));

          if (response.statusCode == 200) {
            expect(response.isRedirect, false);
            if (response case BaseResponseWithUrl(url: final url)) {
              expect(url, Uri.http(loopback2, '/'));
            }

            final [server2, method2, body2, headers2] =
                await httpServerQueue.next as List<Object?>;
            expect(server2, 'server2');
            expect(method2, 'POST');
            expect(body2, 'Hello World!');
            expect(headers2, containsPair('host', [loopback2]));
            expect(headers2, containsPair('hello', ['world']));
            expect(headers2, isNot(contains('authorization')));
            expect(headers2, isNot(contains('cookie')));
            expect(headers2, isNot(contains('proxy-authorization')));
          }
        });
      }
    },
        skip: correctCrossHostRedirect
            ? false
            : 'not opted into cross origin redirect tests');
  });
}
