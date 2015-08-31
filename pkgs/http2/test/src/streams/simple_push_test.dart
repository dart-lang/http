// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.test.streams.simple_push_test;

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:http2/transport.dart';

import 'helper.dart';

main() {
  group('streams', () {
    group('server-push', () {
      const int numOfOneKB = 1000;

      var expectedHeaders = [new Header.ascii('key', 'value')];
      var allBytes = new List.generate(numOfOneKB * 1024, (i) => i % 256);
      allBytes.addAll(new List.generate(42, (i) => 42));

      testHeaders(List<Header> headers) {
        expect(headers.length, expectedHeaders.length);
        for (int i = 0; i < headers.length; i++) {
          expect(headers[i].name, expectedHeaders[i].name);
          expect(headers[i].value, expectedHeaders[i].value);
        }
      }

      headersTestFun() {
        return expectAsync((StreamMessage msg) {
          expect(msg is HeadersStreamMessage, isTrue);
          testHeaders((msg as HeadersStreamMessage).headers);
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
          var pushStream = sStream.push(expectedHeaders);
          pushStream.sendHeaders(expectedHeaders);
          await sendData(pushStream, 'pushing "hello world" :)');

          sStream.incomingMessages.drain();
          sStream.sendHeaders(expectedHeaders, endStream: true);

          expect(await serverReceivedAllBytes.future, completes);
        }));

        ClientTransportStream cStream =
            client.makeRequest(expectedHeaders, endStream: true);
        cStream.incomingMessages.listen(
            headersTestFun(), onDone: expectAsync(() { }));
        cStream.peerPushes.listen(expectAsync((TransportStreamPush push) async {
          testHeaders(push.requestHeaders);

          var iterator = new StreamIterator(push.stream.incomingMessages);
          bool hasNext = await iterator.moveNext();
          expect(hasNext, isTrue);
          testHeaders(iterator.current.headers);

          String msg = await readData(iterator);
          expect(msg, 'pushing "hello world" :)');
        }));
      });
    });
  });
}
