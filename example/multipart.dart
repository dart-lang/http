// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:http/http.dart' as http;

import 'util.dart';

main() async {
  // Open a file for reading to create a stream
  var fileStream = new File('example/upload.txt').openRead();

  // Reads from the stream to create a multipart file
  var file = await http.MultipartFile.loadStream('file', fileStream);

  // Create the multipart request
  var request = new http.Request.multipart('https://httpbin.org/anything',
      fields: <String, String>{
        'dart': 'The programming language used',
        'http': 'The package used for this request',
      },
      files: [
        file
      ]);

  // Create a client
  var client = new http.Client();
  var response = await client.send(request);

  // Read the response
  var responseText = await response.readAsString();

  printHttpBin(responseText);

  // Close the client
  client.close();
}
