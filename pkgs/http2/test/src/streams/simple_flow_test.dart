// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:http2/transport.dart';

import 'helper.dart';

void main() {
  group('streams', () {
    group('flowcontrol', () {
      const numOfOneKB = 1000;

      var expectedHeaders = [Header.ascii('key', 'value')];
      var allBytes = List.generate(numOfOneKB * 1024, (i) => i % 256);
      allBytes.addAll(List.generate(42, (i) => 42));

      void Function(StreamMessage) headersTestFun(String type) {
        return expectAsync1((StreamMessage msg) {
          expect(
              msg,
              isA<HeadersStreamMessage>()
                  .having((m) => m.headers.first.name, 'headers.first.name',
                      expectedHeaders.first.name)
                  .having((m) => m.headers.first.value, 'headers.first.value',
                      expectedHeaders.first.value));
        });
      }

      var serverReceivedAllBytes = Completer();

      void Function(StreamMessage) messageTestFun(String type) {
        var expectHeader = true;
        var numBytesReceived = 0;
        return (StreamMessage msg) {
          if (expectHeader) {
            expectHeader = false;
            expect(
                msg,
                isA<HeadersStreamMessage>()
                    .having((m) => m.headers.first.name, 'headers.first.name',
                        expectedHeaders.first.name)
                    .having((m) => m.headers.first.value, 'headers.first.value',
                        expectedHeaders.first.value));
          } else {
            expect(msg, isA<DataStreamMessage>());
            var bytes = (msg as DataStreamMessage).bytes;
            expect(
                bytes,
                allBytes.sublist(
                    numBytesReceived, numBytesReceived + bytes.length));
            numBytesReceived += bytes.length;

            if (numBytesReceived > allBytes.length) {
              if (serverReceivedAllBytes.isCompleted) {
                throw Exception('Got more messages than expected');
              }
              serverReceivedAllBytes.complete();
            }
          }
        };
      }

      void sendData(TransportStream cStream) {
        for (var i = 0; i < (allBytes.length + 1023) ~/ 1024; i++) {
          var end = 1024 * (i + 1);
          var isLast = end > allBytes.length;
          if (isLast) {
            end = allBytes.length;
          }
          cStream.sendData(allBytes.sublist(1024 * i, end), endStream: isLast);
        }
      }

      streamTest('single-header-request--empty-response',
          (ClientTransportConnection client,
              ServerTransportConnection server) async {
        server.incomingStreams
            .listen(expectAsync1((TransportStream sStream) async {
          sStream.incomingMessages
              .listen(messageTestFun('server'), onDone: expectAsync0(() {}));
          sStream.sendHeaders(expectedHeaders, endStream: true);
          expect(await serverReceivedAllBytes.future, completes);
        }));

        TransportStream cStream = client.makeRequest(expectedHeaders);
        sendData(cStream);
        cStream.incomingMessages
            .listen(headersTestFun('client'), onDone: expectAsync0(() {}));
      });
    });
  });
}
