// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  late Uri url;
  setUp(() async {
    final channel = spawnHybridUri(Uri(path: '/test/stub_server.dart'));
    var port = (await channel.stream.first as num).toInt();
    url = echoUrl.replace(port: port);
  });

  test('#send a GET with default type', () async {
    var client = BrowserClient(cacheMode: CacheMode.defaultType);
    await client.get(url);
    var response = await client.get(url);
    client.close();

    expect(response.statusCode, 200);
    expect(response.reasonPhrase, 'OK');
    expect(response.body, parse(allOf(containsPair('numOfRequests', 1))));
  });

  test('#send a GET Request with reload type', () async {
    var client = BrowserClient(cacheMode: CacheMode.reload);
    await client.get(url);
    var response = await client.get(url);
    expect(response.body, parse(allOf(containsPair('numOfRequests', 2))));
    client.close();
  });

  test('#send a GET with no-cache type', () async {
    var client = BrowserClient(cacheMode: CacheMode.noCache);

    await client.get(url);
    var response = await client.get(url);
    client.close();
    expect(
        response.body,
        parse(anyOf(containsPair('numOfRequests', 2),
            containsPair('cache-control', ['max-age=0']))));
  });

  test('#send a GET with no-store type', () async {
    var client = BrowserClient(cacheMode: CacheMode.noStore);

    await client.get(url);
    var response = await client.get(url);
    client.close();
    expect(response.body, parse(allOf(containsPair('numOfRequests', 2))));
  });

  test('#send a GET with force-store type', () async {
    var client = BrowserClient(cacheMode: CacheMode.forceCache);

    await client.get(url);
    var response = await client.get(url);
    client.close();
    expect(response.body, parse(allOf(containsPair('numOfRequests', 1))));
  });

  test('#send a StreamedRequest with only-if-cached type', () {
    var client = BrowserClient(cacheMode: CacheMode.onlyIfCached);
    var request = http.StreamedRequest('GET', url);

    expectLater(client.send(request), throwsA(isA<ClientException>()));
    unawaited(request.sink.close());

    client.close();
  });
}
