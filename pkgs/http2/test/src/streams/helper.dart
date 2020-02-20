// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import 'package:http2/transport.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/settings/settings.dart';

void expectHeadersEqual(List<Header> headers, List<Header> expectedHeaders) {
  expect(headers, hasLength(expectedHeaders.length));
  for (var i = 0; i < expectedHeaders.length; i++) {
    expect(headers[i].name, expectedHeaders[i].name);
    expect(headers[i].value, expectedHeaders[i].value);
  }
}

void expectEmptyStream(Stream s) {
  s.listen(expectAsync1((_) {}, count: 0), onDone: expectAsync0(() {}));
}

void streamTest(
    String name,
    Future<void> Function(ClientTransportConnection, ServerTransportConnection)
        func,
    {ClientSettings settings}) {
  return test(name, () {
    var bidirect = BidirectionalConnection();
    bidirect.settings = settings;
    var client = bidirect.clientConnection;
    var server = bidirect.serverConnection;
    return func(client, server);
  });
}

void framesTest(
    String name, Future<void> Function(FrameWriter, FrameReader) func) {
  return test(name, () {
    var c = StreamController<List<int>>();
    var fw = FrameWriter(null, c, ActiveSettings());
    var frameStream = FrameReader(c.stream, ActiveSettings());

    return func(fw, frameStream);
  });
}

class BidirectionalConnection {
  ClientSettings settings;
  final StreamController<List<int>> writeA = StreamController();
  final StreamController<List<int>> writeB = StreamController();
  Stream<List<int>> get readA => writeA.stream;
  Stream<List<int>> get readB => writeB.stream;

  ClientTransportConnection get clientConnection =>
      ClientTransportConnection.viaStreams(readA, writeB, settings: settings);

  ServerTransportConnection get serverConnection =>
      ServerTransportConnection.viaStreams(readB, writeA);
}
