// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/src/request.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  test('handles a request', () async {
    var client = MockClient((request) async => http.Response(
        json.encode(request.bodyFields), 200,
        request: request, headers: {'content-type': 'application/json'}));

    var response = await client.post(Uri.http('example.com', '/foo'),
        body: {'field1': 'value1', 'field2': 'value2'});
    expect(
        response.body, parse(equals({'field1': 'value1', 'field2': 'value2'})));
  });

  test('handles a streamed request', () async {
    var client = MockClient.streaming((request, bodyStream) async {
      var bodyString = await bodyStream.bytesToString();
      var stream =
          Stream.fromIterable(['Request body was "$bodyString"'.codeUnits]);
      return http.StreamedResponse(stream, 200);
    });

    var uri = Uri.http('example.com', '/foo');
    var request = http.Request('POST', uri)..body = 'hello, world';
    var streamedResponse = await client.send(request);
    var response = await http.Response.fromStream(streamedResponse);
    expect(response.body, equals('Request body was "hello, world"'));
  });

  test('handles a request with no body', () async {
    var client = MockClient((_) async => http.Response('you did it', 200));

    expect(await client.read(Uri.http('example.com', '/foo')),
        equals('you did it'));
  });

  test('pngResponse with default options', () {
    final response = MockClient.pngResponse();
    expect(response.statusCode, 200);
    expect(response.bodyBytes.take(8),
        [137, 80, 78, 71, 13, 10, 26, 10] // PNG header
        );
    expect(response.request, null);
    expect(response.headers, containsPair('content-type', 'image/png'));
  });

  test('pngResponse with request', () {
    final request = Request('GET', Uri.https('example.com'));
    final response = MockClient.pngResponse(request: request);
    expect(response.statusCode, 200);
    expect(response.bodyBytes.take(8),
        [137, 80, 78, 71, 13, 10, 26, 10] // PNG header
        );
    expect(response.request, request);
    expect(response.headers, containsPair('content-type', 'image/png'));
  });
}
