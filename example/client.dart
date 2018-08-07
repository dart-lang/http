// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http/http.dart' as http;

main() async {
  var url = 'https://httpbin.org/post';
  var client = new http.Client();
  var response = await client.post(url, <String, String>{
    'name': 'doodle',
    'color': 'blue',
  });
  var responseText = await response.readAsString();

  print(response.statusCode);
  print(responseText);

  client.close();
}
