// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.test.streams.simple_push_test;

import 'dart:async';
import 'dart:convert';

import 'package:unittest/unittest.dart';
import 'package:http2/transport.dart';

import 'helper.dart';

main() {
  group('streams', () {
    group('server-push', () {
      const int numOfOneKB = 1000;

      var expectedHeaders = [new Header.ascii('key', 'value')];
      var allBytes = new List.generate(numOfOneKB * 1024, (i) => i % 256);
      allBytes.addAll(new List.generate(42, (i) => 42));

      headersTestFun() {
        return expectAsync((StreamMessage msg) {
          expect(msg is HeadersStreamMessage, isTrue);
          expect((msg as HeadersStreamMessage).headers.first.name,
          expectedHeaders.first.name);
          expect((msg as HeadersStreamMessage).headers.first.value,
          expectedHeaders.first.value);
        });
      }

      Completer serverReceivedAllBytes = new Completer();

      Future<String> readData(StreamIterator<StreamMessage> iterator) async {
        var all = [];

        while (await iterator.moveNext()) {
          var msg = iterator.current;
          expect(msg is DataStreamMessage, isTrue);
          all.addAll(msg.bytes);
        }

        return UTF8.decode(all);
      }


      Future sendData(TransportStream stream, String data) {
        stream.outgoingMessages
          ..add(new DataStreamMessage(UTF8.encode(data)))
          ..close();
        return stream.outgoingMessages.done;
      }

      streamTest('server-push',
          (ClientTransportConnection client,
           ServerTransportConnection server) async {
        server.incomingStreams.listen(
            expectAsync((ServerTransportStream sStream) async {
          sStream.incomingMessages.drain();

          sStream.sendHeaders(expectedHeaders, endStream: true);

          var pushStream = sStream.push(expectedHeaders);
          pushStream.sendHeaders(expectedHeaders);
          await sendData(pushStream, 'pushing "hello world" :)');

          expect(await serverReceivedAllBytes.future, completes);
        }));

        ClientTransportStream cStream =
            client.makeRequest(expectedHeaders, endStream: true);
        cStream.incomingMessages.listen(
            headersTestFun(), onDone: expectAsync(() { }));
        cStream.peerPushes.listen(expectAsync((TransportStreamPush push) async {
          expect(push.requestHeaders, expectedHeaders);

          var iterator = new StreamIterator(push.stream.incomingMessages);
          bool hasNext = await iterator.moveNext();
          expect(hasNext, isTrue);
          headersTestFun()(iterator.current);

          String msg = await readData(iterator);
          expect(msg, 'pushing "hello iworld" :)');
        }));
      });
    });
  });
}
