// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')

import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  test('#send a StreamedRequest', () {
    var client = BrowserClient();
    var request = http.StreamedRequest("POST", echoUrl);

    expect(
        client.send(request).then((response) {
          return response.stream.bytesToString();
        }).whenComplete(client.close),
        completion(equals('{"hello": "world"}')));

    request.sink.add('{"hello": "world"}'.codeUnits);
    request.sink.close();
  }, skip: 'Need to fix server tests for browser');

  test('#send with an invalid URL', () {
    var client = BrowserClient();
    var url = Uri.parse('http://http.invalid');
    var request = http.StreamedRequest("POST", url);

    expect(
        client.send(request), throwsClientException("XMLHttpRequest error."));

    request.sink.add('{"hello": "world"}'.codeUnits);
    request.sink.close();
  });
}
