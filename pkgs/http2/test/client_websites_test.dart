// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show Utf8Decoder, utf8;
import 'dart:io';

import 'package:http2/src/testing/client.dart';
import 'package:pedantic/pedantic.dart';
import 'package:test/test.dart';

void main() async {
  test('google', () async {
    var uri = Uri.parse('https://www.google.com/');
    var connection = await connect(uri);
    var response = await connection.makeRequest(Request('GET', uri));
    dumpHeaders(uri, response.headers);

    final utf8Decoder = Utf8Decoder(allowMalformed: true);
    var body = await response.stream.transform(utf8Decoder).join('');
    unawaited(connection.close());

    body = body.toLowerCase();
    expect(body, contains('<html'));
    expect(body, contains('www.google'));
  });

  test('twitter', () async {
    var uri = Uri.parse('https://twitter.com/');
    var connection = await connect(uri);
    var response = await connection.makeRequest(Request('GET', uri));
    dumpHeaders(uri, response.headers);

    var body = await readBody(response);
    unawaited(connection.close());

    expect(body, contains('<!DOCTYPE html>'));
    expect(body, contains('twitter.com'));
  });

  group('nghttp2.org - ', () {
    test('server push enabled', () async {
      var uri = Uri.parse('https://nghttp2.org/');

      var connection = await connect(uri, allowServerPushes: true);
      var request = Request('GET', uri);
      var response = await connection.makeRequest(request);
      dumpHeaders(uri, response.headers);

      Future<List<List>> accumulatePushes() async {
        var futures = <Future<List>>[];
        return response.serverPushes
            .listen((ServerPush push) {
              futures.add(push.response.then((Response response) {
                dumpHeaders(uri, push.requestHeaders,
                    msg: '**push** Request headers for push request.');
                dumpHeaders(uri, response.headers,
                    msg: '**push** Response headers for server push '
                        'request.');

                return readBody(response).then((String body) {
                  return [push.requestHeaders[':path'].join(''), body];
                });
              }));
            })
            .asFuture()
            .then((_) => Future.wait(futures));
      }

      var results = await Future.wait([readBody(response), accumulatePushes()]);

      var body = results[0];
      expect(body, contains('<!DOCTYPE html>'));
      expect(body, contains('nghttp2'));

      var pushes = results[1] as List<List>;
      expect(pushes, hasLength(1));
      expect(pushes[0][0], '/stylesheets/screen.css');
      expect(pushes[0][1], contains('audio,video{'));
      await connection.close();
    });

    test('server push disabled', () async {
      var uri = Uri.parse('https://nghttp2.org/');

      var connection = await connect(uri, allowServerPushes: false);
      var request = Request('GET', uri);
      var response = await connection.makeRequest(request);
      dumpHeaders(uri, response.headers);

      Future<List<List>> accumulatePushes() async {
        var futures = <Future<List>>[];
        return response.serverPushes
            .listen((ServerPush push) {
              futures.add(push.response
                  .then((Response response) => response.stream.drain()));
            })
            .asFuture()
            .then((_) => Future.wait(futures));
      }

      var results = await Future.wait([readBody(response), accumulatePushes()]);

      var body = results[0];
      expect(body, contains('<!DOCTYPE html>'));
      expect(body, contains('nghttp2'));

      var pushes = results[1];
      expect(pushes, hasLength(0));
      await connection.close();
    });
  }, tags: ['flaky']);
}

void dumpHeaders(Uri uri, Map<String, List<String>> headers,
    {String msg = 'Response headers.'}) {
  print('');
  print('[$uri]  $msg');
  for (var key in headers.keys.toList()..sort()) {
    var spaces = ' ' * (20 - key.length);
    print('$key   $spaces ${headers[key].join(', ')}');
  }
  print('');
}

Future<String> readBody(Response response) async {
  var stream = response.stream;
  if (response.headers['content-encoding']?.join('') == 'gzip') {
    stream = stream.transform(gzip.decoder);
  } else if (response.headers['content-encoding']?.join('') == 'deflate') {
    stream = stream.transform(zlib.decoder);
  }
  return await stream.transform(utf8.decoder).join('');
}
