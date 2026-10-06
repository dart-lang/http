// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http2/transport.dart';
import 'package:test/test.dart';

void main() {
  late ClientTransportConnection client;
  late ServerTransportConnection server;
  late StreamIterator<ServerTransportStream> requests;

  setUp(() async {
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(listener.close);
    final accepted = Completer<Socket>();
    listener.listen(accepted.complete);
    final clientSocket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      listener.port,
    );
    addTearDown(clientSocket.destroy);
    final serverSocket = await accepted.future;
    addTearDown(serverSocket.destroy);
    client = ClientTransportConnection.viaSocket(clientSocket);
    server = ServerTransportConnection.viaSocket(serverSocket);
    addTearDown(() async {
      await [client.terminate(), server.terminate()].wait;
    });
    requests = StreamIterator(server.incomingStreams);
    addTearDown(requests.cancel);
  });

  Future<void> checkResponse(int length, {bool closeSink = false}) async {
    final request = client.makeRequest([
      Header.ascii(':method', 'GET'),
      Header.ascii(':path', '/'),
      Header.ascii(':scheme', 'http'),
      Header.ascii(':authority', 'localhost'),
    ], endStream: true);
    final body = Uint8List.fromList(List.generate(length, (i) => i % 251));
    final received = BytesBuilder();
    var endStreamMessages = 0;
    final responseDone = request.incomingMessages.forEach((message) {
      if (message is DataStreamMessage) received.add(message.bytes);
      if (message.endStream) endStreamMessages++;
    });
    expect(await requests.moveNext(), isTrue);
    final response = requests.current;
    await response.incomingMessages.drain<void>();
    response.sendHeaders([Header.ascii(':status', '200')]);
    if (closeSink) {
      await response.outgoingMessages.addStream(
        Stream.value(DataStreamMessage(body)),
      );
      unawaited(response.outgoingMessages.close());
    } else {
      response.sendData(body, endStream: true);
    }
    await responseDone.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('Response stalled after ${received.length} bytes'),
    );
    expect(received.takeBytes(), body);
    // Empty DATA frames close the incoming stream without a stream message.
    expect(endStreamMessages, closeSink || length == 0 ? 0 : 1);
    await client.ping();
    await server.ping();
  }

  for (final length in [0, 1, 65535, 65536, 200000]) {
    test('sendData with endStream delivers $length bytes over TCP', () async {
      await checkResponse(length);
    });
  }

  test(
    'closing the outgoing sink delivers a large response over TCP',
    () async {
      await checkResponse(200000, closeSink: true);
    },
  );
}
