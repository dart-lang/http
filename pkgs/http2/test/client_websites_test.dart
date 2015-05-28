// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.test.client_websites_test;

import 'dart:async';
import 'dart:convert';

import 'package:http2/client.dart';
import 'package:unittest/unittest.dart';

main() async {
  group('end2end', () {
    test('google', () async {
      var uri = Uri.parse("https://www.google.com/");
      ClientConnection connection = await connect(uri);
      Response response = await connection.makeRequest(new Request('GET', uri));
      dumpHeaders(uri, response.headers);

      String body = await response.stream.transform(UTF8.decoder).join('');
      connection.close();

      body = body.toLowerCase();
      expect(body, contains('<html>'));
      expect(body, contains('www.google'));
    });

    test('twitter', () async {
      var uri = Uri.parse("https://twitter.com/");
      ClientConnection connection = await connect(uri);
      Response response = await connection.makeRequest(new Request('GET', uri));
      dumpHeaders(uri, response.headers);

      String body = await response.stream.transform(UTF8.decoder).join('');
      connection.close();

      expect(body, contains('<!DOCTYPE html>'));
      expect(body, contains('twitter.com'));
    });

    test('nghttp2.org - server push enabled', () async {
      var uri = Uri.parse("https://nghttp2.org/");

      ClientConnection connection = await connect(uri, allowServerPushes: true);
      var request = new Request('GET', uri);
      Response response = await connection.makeRequest(request);
      dumpHeaders(uri, response.headers);

      Future<String> accumulateResponse(stream) async {
        return await stream.transform(UTF8.decoder).join('');
      }

      Future<List<List>> accumulatePushes() async {
        var futures = [];
        return response.serverPushes.listen((ServerPush push) {
          futures.add(push.response.then((Response response) {
            dumpHeaders(uri, push.requestHeaders,
                        msg: '**push** Request headers for push request.');
            dumpHeaders(uri, response.headers,
                        msg: '**push** Response headers for server push '
                             'request.');

            return accumulateResponse(response.stream).then((String body) {
              return [push.requestHeaders[':path'].join(''), body];
            });
          }));
        }).asFuture().then((_) => Future.wait(futures));
      }

      var results = await Future.wait(
          [accumulateResponse(response.stream), accumulatePushes()]);

      var body = results[0];
      expect(body, contains('<!DOCTYPE html>'));
      expect(body, contains('nghttp2'));

      // TODO: Find out why the push we get is a 502, it should be 200 with a
      // css file. WTF?
      var pushes = results[1];
      expect(pushes, hasLength(1));
      expect(pushes[0][0], '/stylesheets/screen.css');
      expect(pushes[0][1], contains('Bad Gateway'));
      await connection.close();
    });

    test('nghttp2.org - server push disabled', () async {
      var uri = Uri.parse("https://nghttp2.org/");

      ClientConnection connection = await connect(
          uri, allowServerPushes: false);
      var request = new Request('GET', uri);
      Response response = await connection.makeRequest(request);
      dumpHeaders(uri, response.headers);

      Future<String> accumulateResponse(stream) async {
        return await stream.transform(UTF8.decoder).join('');
      }

      Future<List<List>> accumulatePushes() async {
        var futures = [];
        return response.serverPushes.listen((ServerPush push) {
          futures.add(push.response.then(
                  (Response response) => response.stream.drain()));
        }).asFuture().then((_) => Future.wait(futures));
      }

      var results = await Future.wait(
          [accumulateResponse(response.stream), accumulatePushes()]);

      var body = results[0];
      expect(body, contains('<!DOCTYPE html>'));
      expect(body, contains('nghttp2'));

      var pushes = results[1];
      expect(pushes, hasLength(0));
      await connection.close();
    });
  });
}

dumpHeaders(Uri uri, Map<String, List<String>> headers,
            {String msg: 'Response headers.'}) {
  print('');
  print('[$uri]  $msg');
  for (var key in headers.keys.toList()..sort()) {
    var spaces = ' ' * (20 - key.length);
    print('$key   $spaces ${headers[key].join(', ')}');
  }
  print('');
}

