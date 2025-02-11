// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'utils.dart';

void main() {

  test('#send a StreamedRequest with default type', () async {
    var client = BrowserClient(cacheMode: CacheMode.defaultType);
    var request = http.StreamedRequest('POST',echoUrl);

    var responseFuture = client.send(request);
    request.sink.add('{"hello": "world"}'.codeUnits);
    unawaited(request.sink.close());
    var response = await responseFuture;
    var bytesString = await response.stream.bytesToString();

    final jsonResponse = jsonDecode(bytesString);
    var bodyUnits = jsonResponse['body'] as List;
    client.close();

    expect(bodyUnits,
        equals('{"hello": "world"}'.codeUnits));
  });

  test('#send a StreamedRequest with reload type', () async {
    var client = BrowserClient(cacheMode: CacheMode.reload);
    var request = http.StreamedRequest('POST',echoUrl);

    var responseFuture = client.send(request);
    request.sink.add('{"hello": "world"}'.codeUnits);
    unawaited(request.sink.close());
    var response = await responseFuture;
    var bytesString = await response.stream.bytesToString();

    final jsonResponse = jsonDecode(bytesString);
    client.close();

    expect(jsonResponse["headers"]["cache-control"],
        contains('no-cache'));
  });

  test('#send a StreamedRequest with no-cache type', () async {
    var client = BrowserClient(cacheMode: CacheMode.noCache);
    var request = http.StreamedRequest('POST',echoUrl);

    var responseFuture = client.send(request);
    request.sink.add('{"hello": "world"}'.codeUnits);
    unawaited(request.sink.close());
    var response = await responseFuture;
    var bytesString = await response.stream.bytesToString();

    final jsonResponse = jsonDecode(bytesString);
    client.close();

    expect(jsonResponse["headers"]["cache-control"],
        contains('max-age=0'));
  });
}
