// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http2/transport.dart';
import 'package:pedantic/pedantic.dart';
import 'package:test/test.dart';

import 'helper.dart';

void main() {
  group('streams', () {
    streamTest('single-header-request--empty-response',
        (ClientTransportConnection client,
            ServerTransportConnection server) async {
      var expectedHeaders = [Header.ascii('key', 'value')];

      server.incomingStreams.listen(expectAsync1((TransportStream sStream) {
        sStream.incomingMessages.listen(expectAsync1((StreamMessage msg) {
          expect(msg, isA<HeadersStreamMessage>());

          var headersMsg = msg as HeadersStreamMessage;
          expectHeadersEqual(headersMsg.headers, expectedHeaders);
        }), onDone: expectAsync0(() {}));
        sStream.outgoingMessages.close();
      }));

      TransportStream cStream =
          client.makeRequest(expectedHeaders, endStream: true);
      expectEmptyStream(cStream.incomingMessages);
    });

    streamTest('multi-header-request--empty-response',
        (ClientTransportConnection client,
            ServerTransportConnection server) async {
      var expectedHeaders = [Header.ascii('key', 'value')];

      server.incomingStreams.listen(expectAsync1((TransportStream sStream) {
        sStream.incomingMessages.listen(
            expectAsync1((StreamMessage msg) {
              expect(msg, isA<HeadersStreamMessage>());

              var headersMsg = msg as HeadersStreamMessage;
              expectHeadersEqual(headersMsg.headers, expectedHeaders);
            }, count: 3),
            onDone: expectAsync0(() {}));
        sStream.outgoingMessages.close();
      }));

      TransportStream cStream = client.makeRequest(expectedHeaders);
      cStream.sendHeaders(expectedHeaders);
      cStream.sendHeaders(expectedHeaders, endStream: true);
      expectEmptyStream(cStream.incomingMessages);
    });

    streamTest('multi-data-request--empty-response',
        (ClientTransportConnection client,
            ServerTransportConnection server) async {
      var expectedHeaders = [Header.ascii('key', 'value')];
      var chunks = [
        [1],
        [2],
        [3]
      ];

      server.incomingStreams
          .listen(expectAsync1((TransportStream sStream) async {
        var isFirst = true;
        var receivedChunks = [];
        sStream.incomingMessages.listen(
            expectAsync1((StreamMessage msg) {
              if (isFirst) {
                isFirst = false;
                expect(msg, isA<HeadersStreamMessage>());

                var headersMsg = msg as HeadersStreamMessage;
                expectHeadersEqual(headersMsg.headers, expectedHeaders);
              } else {
                expect(msg, isA<DataStreamMessage>());

                var dataMsg = msg as DataStreamMessage;
                receivedChunks.add(dataMsg.bytes);
              }
            }, count: 1 + chunks.length), onDone: expectAsync0(() {
          expect(receivedChunks, chunks);
        }));
        unawaited(sStream.outgoingMessages.close());
      }));

      TransportStream cStream = client.makeRequest(expectedHeaders);
      chunks.forEach(cStream.sendData);
      unawaited(cStream.outgoingMessages.close());
      expectEmptyStream(cStream.incomingMessages);
    });

    streamTest('single-header-request--single-headers-response',
        (ClientTransportConnection client,
            ServerTransportConnection server) async {
      var expectedHeaders = [Header.ascii('key', 'value')];

      server.incomingStreams.listen(expectAsync1((TransportStream sStream) {
        sStream.incomingMessages.listen(expectAsync1((StreamMessage msg) {
          expect(msg, isA<HeadersStreamMessage>());

          var headersMsg = msg as HeadersStreamMessage;
          expectHeadersEqual(headersMsg.headers, expectedHeaders);
        }), onDone: expectAsync0(() {}));
        sStream.sendHeaders(expectedHeaders, endStream: true);
      }));

      TransportStream cStream =
          client.makeRequest(expectedHeaders, endStream: true);

      cStream.incomingMessages.listen(expectAsync1((StreamMessage msg) {
        expect(msg, isA<HeadersStreamMessage>());

        var headersMsg = msg as HeadersStreamMessage;
        expectHeadersEqual(headersMsg.headers, expectedHeaders);
      }), onDone: expectAsync0(() {}));
    });

    streamTest('single-header-request--multi-headers-response',
        (ClientTransportConnection client,
            ServerTransportConnection server) async {
      var expectedHeaders = [Header.ascii('key', 'value')];

      server.incomingStreams.listen(expectAsync1((TransportStream sStream) {
        sStream.incomingMessages.listen(expectAsync1((StreamMessage msg) {
          expect(msg, isA<HeadersStreamMessage>());

          var headersMsg = msg as HeadersStreamMessage;
          expectHeadersEqual(headersMsg.headers, expectedHeaders);
        }), onDone: expectAsync0(() {}));

        sStream.sendHeaders(expectedHeaders);
        sStream.sendHeaders(expectedHeaders);
        sStream.sendHeaders(expectedHeaders, endStream: true);
      }));

      TransportStream cStream =
          client.makeRequest(expectedHeaders, endStream: true);

      cStream.incomingMessages.listen(expectAsync1((StreamMessage msg) {
        expect(msg, isA<HeadersStreamMessage>());

        var headersMsg = msg as HeadersStreamMessage;
        expectHeadersEqual(headersMsg.headers, expectedHeaders);
      }, count: 3));
    });

    streamTest('single-header-request--multi-data-response',
        (ClientTransportConnection client,
            ServerTransportConnection server) async {
      var expectedHeaders = [Header.ascii('key', 'value')];
      var chunks = [
        [1],
        [2],
        [3]
      ];

      server.incomingStreams.listen(expectAsync1((TransportStream sStream) {
        sStream.incomingMessages.listen(expectAsync1((StreamMessage msg) {
          expect(msg, isA<HeadersStreamMessage>());

          var headersMsg = msg as HeadersStreamMessage;
          expectHeadersEqual(headersMsg.headers, expectedHeaders);
        }), onDone: expectAsync0(() {}));

        chunks.forEach(sStream.sendData);
        sStream.outgoingMessages.close();
      }));

      TransportStream cStream = client.makeRequest(expectedHeaders);
      unawaited(cStream.outgoingMessages.close());

      var i = 0;
      cStream.incomingMessages.listen(expectAsync1((StreamMessage msg) {
        expect(
            msg,
            isA<DataStreamMessage>()
                .having((m) => m.bytes, 'bytes', chunks[i++]));
      }, count: chunks.length));
    });
  });

  streamTest('single-data-request--data-trailer-response',
      (ClientTransportConnection client,
          ServerTransportConnection server) async {
    var expectedHeaders = [Header.ascii('key', 'value')];
    var chunk = [1];

    server.incomingStreams.listen(expectAsync1((TransportStream sStream) async {
      var isFirst = true;
      var receivedChunk;
      sStream.incomingMessages.listen(
          expectAsync1((StreamMessage msg) {
            if (isFirst) {
              isFirst = false;
              expect(msg, isA<HeadersStreamMessage>());
              expect(msg.endStream, false);

              var headersMsg = msg as HeadersStreamMessage;
              expectHeadersEqual(headersMsg.headers, expectedHeaders);
            } else {
              expect(msg, isA<DataStreamMessage>());
              expect(msg.endStream, true);
              expect(receivedChunk, null);

              var dataMsg = msg as DataStreamMessage;
              receivedChunk = dataMsg.bytes;
            }
          }, count: 2), onDone: expectAsync0(() {
        expect(receivedChunk, chunk);
        sStream.sendData([2]);
        sStream.sendHeaders(expectedHeaders, endStream: true);
      }));
    }));

    TransportStream cStream = client.makeRequest(expectedHeaders);
    cStream.sendData(chunk, endStream: true);

    var isFirst = true;
    cStream.incomingMessages.listen(expectAsync1((StreamMessage msg) {
      if (isFirst) {
        expect(msg, const TypeMatcher<DataStreamMessage>());
        final data = msg as DataStreamMessage;
        expect(data.bytes, [2]);
        isFirst = false;
      } else {
        expect(msg, const TypeMatcher<HeadersStreamMessage>());
        final trailer = msg as HeadersStreamMessage;
        expect(trailer.endStream, true);
        expectHeadersEqual(trailer.headers, expectedHeaders);
      }
    }, count: 2));
  });
}
