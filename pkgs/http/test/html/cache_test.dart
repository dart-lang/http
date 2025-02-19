// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/src/exception.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  late int port;
  setUp(() async {
    final channel = spawnHybridUri(Uri(path: '/test/stub_server.dart'),
        stayAlive: true);
    port = await channel.stream.first as int;
  });

  test('#send a POST Request with default type', () async {
    var client = BrowserClient();

    var request = http.StreamedRequest('POST', echoUrl.replace(port: port));
    var responseFuture = client.send(request);
    request.sink.add('{"hello": "world"}'.codeUnits);
    unawaited(request.sink.close());

    var response = await responseFuture;

    client.close();

    expect(response.statusCode, 200);
    expect('response', response.contentLength);
    client.close();

  });

  test('#send a StreamedRequest with default type', () async {
    var client = BrowserClient(cacheMode: CacheMode.defaultType);
    var request = http.StreamedRequest('POST', echoUrl);
    var responseFuture = client.send(request);
    request.sink.add('{"hello": "world"}'.codeUnits);
    unawaited(request.sink.close());

    var response = await responseFuture;

    client.close();

    expect(response.statusCode, 200);
    expect(response.reasonPhrase, 'OK');
  }, skip: 'Need to fix server tests for browser');

  test('#send a POST Request with reload type', () async {
    var client = BrowserClient(cacheMode: CacheMode.reload);

    var responseFuture = client.post(echoUrl.replace(port: port));

    client.close();

  }, skip: 'Need to fix server tests for browser');

  test('#send a StreamedRequest with no-cache type', () async {
    var client = BrowserClient(cacheMode: CacheMode.noCache);
    var request = http.StreamedRequest('POST', echoUrl);

    var responseFuture = client.send(request);
    request.sink.add('{"hello": "world"}'.codeUnits);
    unawaited(request.sink.close());
    var response = await responseFuture;
    var bytesString = await response.stream.bytesToString();

    client.close();
    expect(bytesString, contains('max-age=0'));
  }, skip: 'Need to fix server tests for browser');

  test('#send a StreamedRequest with only-if-cached type', () {
    var client = BrowserClient(cacheMode: CacheMode.onlyIfCached);
    var request = http.StreamedRequest('POST', echoUrl);

    expectLater(client.send(request), throwsA(isA<ClientException>()));
    request.sink.add('{"hello": "world"}'.codeUnits);
    unawaited(request.sink.close());

    client.close();
  }, skip: 'Need to fix server tests for browser');

  test('#send with an invalid URL', () {
    var client = BrowserClient(cacheMode: CacheMode.onlyIfCached);
    var url = Uri.http('http.invalid', '');
    var request = http.StreamedRequest('POST', url);

    expect(client.send(request), throwsClientException());

    request.sink.add('{"hello": "world"}'.codeUnits);
    request.sink.close();
  }, skip: 'Need to fix server tests for browser');
}
