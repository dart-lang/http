// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:http2/client.dart';

/// Sends several concurrent requests through a single [Http2Client],
/// demonstrating that they share pooled HTTP/2 connections instead of each
/// opening their own.
void main(List<String> args) async {
  if (args.length != 1) {
    print('Usage: dart pooled_client.dart <HTTPS_URI>');
    exit(1);
  }

  final uri = Uri.parse(args[0]);
  final client = Http2Client();

  try {
    final responses = await Future.wait(
      List.generate(5, (_) => client.get(uri)),
    );
    for (final response in responses) {
      print('${response.statusCode}: ${response.body.length} bytes');
    }
    print('Connections used: ${client.connectionCount}');
  } finally {
    // Lets the requests above finish before closing every connection.
    client.close();
  }
}
