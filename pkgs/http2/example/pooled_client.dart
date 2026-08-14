// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http2/client.dart';

/// An endpoint that waits a second before answering, so that the time saved by
/// running requests concurrently is easy to see.
final _slowEndpoint = Uri.https('postman-echo.com', '/delay/1');

const _concurrentRequests = 100;
const _sequentialRequests = 5;

void main() async {
  // `Http2Client` is a `package:http` `Client`, so it can be passed anywhere
  // one is accepted.
  final client = Http2Client();

  // HTTP/2 carries many requests over a single connection at the same time, so
  // all of these are in flight together. HTTP/1.1 has no such thing - it would
  // have needed a connection per request in flight, each paying for its own
  // TCP and TLS handshake, and each holding a socket, a TLS session and its
  // buffers for as long as it stayed open. Multiplexing keeps that footprint
  // flat as concurrency grows, which matters where memory and file descriptors
  // are capped - serverless functions, for instance.
  final concurrent = Stopwatch()..start();
  final responses = await Future.wait([
    for (var i = 0; i < _concurrentRequests; i++) client.get(_slowEndpoint),
  ]);
  concurrent.stop();

  final failures = responses.where((r) => r.statusCode != 200).length;
  if (failures > 0) {
    print('$failures of $_concurrentRequests requests failed.');
  }

  // A handful of the same requests one at a time, to show what they cost
  // without that overlap.
  final sequential = Stopwatch()..start();
  for (var i = 0; i < _sequentialRequests; i++) {
    await client.get(_slowEndpoint);
  }
  sequential.stop();

  print(
    '$_concurrentRequests requests over '
    '${client.connectionCount} connection(s).',
  );
  print('Each one takes about a second of server time:');
  print('  all at once  : ${concurrent.elapsedMilliseconds}ms');
  print(
    '  $_sequentialRequests one by one : '
    '${sequential.elapsedMilliseconds}ms',
  );

  client.close();
}
