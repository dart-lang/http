// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert' as convert;

import 'package:http/http.dart' as http;

void main(List<String> arguments) async {
  // This example uses the pub.dev API to fetch details about package:http.
  // See https://pub.dev/help/api
  var url = Uri.https('pub.dev', '/api/packages/http/score');

  // Await the http get response, then decode the json-formatted response.
  var response = await http.get(url);
  if (response.statusCode == 200) {
    var jsonResponse =
        convert.jsonDecode(response.body) as Map<String, dynamic>;
    var likes = jsonResponse['likeCount'];
    var downloads = jsonResponse['downloadCount30Days'];
    print('Information about package:http:');
    print('- Likes: $likes');
    print('- 30-day downloads: $downloads');
  } else {
    print('Request failed with status: ${response.statusCode}.');
  }
}
