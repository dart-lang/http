// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:http_parser/http_parser.dart';

import 'byte_stream.dart';
import 'multipart_file.dart';

Future<MultipartFile> multipartFileFromPath(String field, String filePath,
    {String? filename, MediaType? contentType}) async {
  late var segments = Uri.file(filePath).pathSegments;
  filename ??= segments.isEmpty ? '' : segments.last;
  var file = File(filePath);
  var length = await file.length();
  var stream = ByteStream(file.openRead());
  return MultipartFile(field, stream, length,
      filename: filename, contentType: contentType);
}
