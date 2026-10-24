// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'test_certificates.dart';

/// Converts a PEM-encoded certificate to DER.
Uint8List pemToDer(String pem) => base64.decode(
  pem
      .split('\n')
      .where((line) => line.isNotEmpty && !line.startsWith('-----'))
      .join(),
);

/// Whether [a] and [b] contain the same elements in the same order.
bool listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; ++i) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Starts a HTTPS server on `localhost` that uses [serverCertificatePem],
/// which is issued by [testCaCertificatePem].
///
/// The server responds to every request with "Hello World".
Future<HttpServer> startSecureServer() async {
  final context = SecurityContext(withTrustedRoots: false)
    ..useCertificateChainBytes(utf8.encode(serverCertificatePem))
    ..usePrivateKeyBytes(utf8.encode(serverKeyPem));
  final server = await HttpServer.bindSecure('localhost', 0, context);
  server.listen((request) async {
    await request.drain<void>();
    request.response.headers.set('Content-Type', 'text/plain');
    request.response.write('Hello World');
    await request.response.close();
  });
  return server;
}
