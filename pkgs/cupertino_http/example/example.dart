// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' as convert;

import 'package:cupertino_http/cupertino_http.dart';

void main(List<String> arguments) async {
  // This example uses the pub.dev API to fetch details about
  // package:cupertino_http.
  // https://pub.dev/help/api
  final client = CupertinoClient.defaultSessionConfiguration();
  final url = Uri.https('pub.dev', '/api/packages/cupertino_http/score');

  // Await the http get response, then decode the json-formatted response.
  final response = await client.get(url);
  if (response.statusCode == 200) {
    var jsonResponse =
        convert.jsonDecode(response.body) as Map<String, dynamic>;
    var likes = jsonResponse['likeCount'];
    var downloads = jsonResponse['downloadCount30Days'];
    print('Information about package:cupertino_http:');
    print('- Likes: $likes');
    print('- 30-day downloads: $downloads');
  } else {
    print('Request failed with status: ${response.statusCode}.');
  }
  client.close();
}
