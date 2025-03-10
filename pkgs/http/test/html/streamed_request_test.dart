// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  late Uri url;
  setUpAll(() async {
    final channel =
        spawnHybridUri(Uri(path: '/test/stub_server.dart'), stayAlive: true);
    var port = await (channel.stream.first as num).toInt();
    url = echoUrl.replace(port: port);
  });
  group('contentLength', () {
    test("works when it's set", () async {
      var request = http.StreamedRequest('POST', url)
        ..contentLength = 10
        ..sink.add([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      unawaited(request.sink.close());

      final response = await BrowserClient().send(request);

      expect(await response.stream.bytesToString(),
          parse(allOf(containsPair('body', [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]))));
    });

    test("works when it's not set", () async {
      var request = http.StreamedRequest('POST', url);
      request.sink.add([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      unawaited(request.sink.close());

      final response = await BrowserClient().send(request);

      expect(await response.stream.bytesToString(),
          parse(allOf(containsPair('body', [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]))));
    });
  });
}
