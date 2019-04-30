// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/src/io_client.dart' as http_io;
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  tearDown(stopServer);

  test('#send a StreamedRequest', () {
    expect(
        startServer().then((_) {
          var client = http.Client();
          var request = http.StreamedRequest("POST", serverUrl);
          request.headers[HttpHeaders.contentTypeHeader] =
              'application/json; charset=utf-8';
          request.headers[HttpHeaders.userAgentHeader] = 'Dart';

          expect(
              client.send(request).then((response) {
                expect(response.request, equals(request));
                expect(response.statusCode, equals(200));
                expect(response.headers['single'], equals('value'));
                // dart:io internally normalizes outgoing headers so that they never
                // have multiple headers with the same name, so there's no way to test
                // whether we handle that case correctly.

                return response.stream.bytesToString();
              }).whenComplete(client.close),
              completion(parse(equals({
                'method': 'POST',
                'path': '/',
                'headers': {
                  'content-type': ['application/json; charset=utf-8'],
                  'accept-encoding': ['gzip'],
                  'user-agent': ['Dart'],
                  'transfer-encoding': ['chunked']
                },
                'body': '{"hello": "world"}'
              }))));

          request.sink.add('{"hello": "world"}'.codeUnits);
          request.sink.close();
        }),
        completes);
  });

  test('#send a StreamedRequest with a custom client', () {
    expect(
        startServer().then((_) {
          var ioClient = HttpClient();
          var client = http_io.IOClient(ioClient);
          var request = http.StreamedRequest("POST", serverUrl);
          request.headers[HttpHeaders.contentTypeHeader] =
              'application/json; charset=utf-8';
          request.headers[HttpHeaders.userAgentHeader] = 'Dart';

          expect(
              client.send(request).then((response) {
                expect(response.request, equals(request));
                expect(response.statusCode, equals(200));
                expect(response.headers['single'], equals('value'));
                // dart:io internally normalizes outgoing headers so that they never
                // have multiple headers with the same name, so there's no way to test
                // whether we handle that case correctly.

                return response.stream.bytesToString();
              }).whenComplete(client.close),
              completion(parse(equals({
                'method': 'POST',
                'path': '/',
                'headers': {
                  'content-type': ['application/json; charset=utf-8'],
                  'accept-encoding': ['gzip'],
                  'user-agent': ['Dart'],
                  'transfer-encoding': ['chunked']
                },
                'body': '{"hello": "world"}'
              }))));

          request.sink.add('{"hello": "world"}'.codeUnits);
          request.sink.close();
        }),
        completes);
  });

  test('#send with an invalid URL', () {
    expect(
        startServer().then((_) {
          var client = http.Client();
          var url = Uri.parse('http://http.invalid');
          var request = http.StreamedRequest("POST", url);
          request.headers[HttpHeaders.contentTypeHeader] =
              'application/json; charset=utf-8';

          expect(client.send(request), throwsSocketException);

          request.sink.add('{"hello": "world"}'.codeUnits);
          request.sink.close();
        }),
        completes);
  });
}
