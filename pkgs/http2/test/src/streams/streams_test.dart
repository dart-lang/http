// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.test.end2end_test;

import 'package:test/test.dart';
import 'package:http2/transport.dart';

import 'helper.dart';

main() {
  group('streams', () {
    streamTest('single-header-request--empty-response',
               (ClientTransportConnection client,
                ServerTransportConnection server) async {
      var expectedHeaders = [new Header.ascii('key', 'value')];

      server.incomingStreams.listen(expectAsync((TransportStream sStream) {
        sStream.incomingMessages.listen(expectAsync((StreamMessage msg) {
          expect(msg is HeadersStreamMessage, isTrue);

          HeadersStreamMessage headersMsg = msg;
          expectHeadersEqual(headersMsg.headers, expectedHeaders);
        }), onDone: expectAsync(() {}));
        sStream.outgoingMessages.close();
      }));

      TransportStream cStream =
          client.makeRequest(expectedHeaders, endStream: true);
      expectEmptyStream(cStream.incomingMessages);
    });

    streamTest('multi-header-request--empty-response',
               (ClientTransportConnection client,
                ServerTransportConnection server) async {
      var expectedHeaders = [new Header.ascii('key', 'value')];

      server.incomingStreams.listen(expectAsync((TransportStream sStream) {
        sStream.incomingMessages.listen(expectAsync((StreamMessage msg) {
          expect(msg is HeadersStreamMessage, isTrue);

          HeadersStreamMessage headersMsg = msg;
          expectHeadersEqual(headersMsg.headers, expectedHeaders);
        }, count: 3), onDone: expectAsync(() {}));
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
      var expectedHeaders = [new Header.ascii('key', 'value')];
      var chunks = [[1], [2], [3]];

      server.incomingStreams.listen(
          expectAsync((TransportStream sStream) async {
        bool isFirst = true;
        var receivedChunks = [];
        sStream.incomingMessages.listen(expectAsync((StreamMessage msg) {
          if (isFirst) {
            isFirst = false;
            expect(msg is HeadersStreamMessage, isTrue);

            HeadersStreamMessage headersMsg = msg;
            expectHeadersEqual(headersMsg.headers, expectedHeaders);
          } else {
            expect(msg is DataStreamMessage, isTrue);

            DataStreamMessage dataMsg = msg;
            receivedChunks.add(dataMsg.bytes);
          }
        }, count: 1 + chunks.length), onDone: expectAsync(() {
          expect(receivedChunks, chunks);
        }));
        sStream.outgoingMessages.close();
      }));

      TransportStream cStream = client.makeRequest(expectedHeaders);
      chunks.forEach(cStream.sendData);
      cStream.outgoingMessages.close();
      expectEmptyStream(cStream.incomingMessages);
    });

    streamTest('single-header-request--single-headers-response',
               (ClientTransportConnection client,
                ServerTransportConnection server) async {
      var expectedHeaders = [new Header.ascii('key', 'value')];

      server.incomingStreams.listen(expectAsync((TransportStream sStream) {
        sStream.incomingMessages.listen(expectAsync((StreamMessage msg) {
          expect(msg is HeadersStreamMessage, isTrue);

          HeadersStreamMessage headersMsg = msg;
          expectHeadersEqual(headersMsg.headers, expectedHeaders);
        }), onDone: expectAsync(() {}));
        sStream.sendHeaders(expectedHeaders, endStream: true);
      }));

      TransportStream cStream =
          client.makeRequest(expectedHeaders, endStream: true);

      cStream.incomingMessages.listen(expectAsync((StreamMessage msg) {
        expect(msg is HeadersStreamMessage, isTrue);

        HeadersStreamMessage headersMsg = msg;
        expectHeadersEqual(headersMsg.headers, expectedHeaders);
      }), onDone: expectAsync(() {}));
    });

    streamTest('single-header-request--multi-headers-response',
               (ClientTransportConnection client,
                ServerTransportConnection server) async {
      var expectedHeaders = [new Header.ascii('key', 'value')];

      server.incomingStreams.listen(expectAsync((TransportStream sStream) {
        sStream.incomingMessages.listen(expectAsync((StreamMessage msg) {
          expect(msg is HeadersStreamMessage, isTrue);

          HeadersStreamMessage headersMsg = msg;
          expectHeadersEqual(headersMsg.headers, expectedHeaders);
        }), onDone: expectAsync(() {}));

        sStream.sendHeaders(expectedHeaders);
        sStream.sendHeaders(expectedHeaders);
        sStream.sendHeaders(expectedHeaders, endStream: true);
      }));

      TransportStream cStream =
          client.makeRequest(expectedHeaders, endStream: true);

      cStream.incomingMessages.listen(expectAsync((StreamMessage msg) {
        expect(msg is HeadersStreamMessage, isTrue);

        HeadersStreamMessage headersMsg = msg;
        expectHeadersEqual(headersMsg.headers, expectedHeaders);
      }, count: 3));
    });

    streamTest('single-header-request--multi-data-response',
               (ClientTransportConnection client,
                ServerTransportConnection server) async {
      var expectedHeaders = [new Header.ascii('key', 'value')];
      var chunks = [[1], [2], [3]];

      server.incomingStreams.listen(expectAsync((TransportStream sStream) {
        sStream.incomingMessages.listen(expectAsync((StreamMessage msg) {
          expect(msg is HeadersStreamMessage, isTrue);

          HeadersStreamMessage headersMsg = msg;
          expectHeadersEqual(headersMsg.headers, expectedHeaders);
        }), onDone: expectAsync(() {}));

        chunks.forEach(sStream.sendData);
        sStream.outgoingMessages.close();
      }));

      TransportStream cStream = client.makeRequest(expectedHeaders);
      cStream.outgoingMessages.close();

      int i = 0;
      cStream.incomingMessages.listen(expectAsync((StreamMessage msg) {
        expect(msg is DataStreamMessage, isTrue);
        expect((msg as DataStreamMessage).bytes, chunks[i++]);
      }, count: chunks.length));
    });
  });

  streamTest('single-data-request--data-trailer-response',
      (ClientTransportConnection client,
          ServerTransportConnection server) async {
    var expectedHeaders = [new Header.ascii('key', 'value')];
    var chunk = [1];

    server.incomingStreams.listen(expectAsync((TransportStream sStream) async {
      bool isFirst = true;
      var receivedChunk;
      sStream.incomingMessages.listen(
          expectAsync((StreamMessage msg) {
            if (isFirst) {
              isFirst = false;
              expect(msg is HeadersStreamMessage, isTrue);
              expect(msg.endStream, false);

              HeadersStreamMessage headersMsg = msg;
              expectHeadersEqual(headersMsg.headers, expectedHeaders);
            } else {
              expect(msg is DataStreamMessage, isTrue);
              expect(msg.endStream, true);
              expect(receivedChunk, null);

              DataStreamMessage dataMsg = msg;
              receivedChunk = dataMsg.bytes;
            }
          }, count: 2), onDone: expectAsync(() {
        expect(receivedChunk, chunk);
        sStream.sendData([2]);
        sStream.sendHeaders(expectedHeaders, endStream: true);
      }));
    }));

    TransportStream cStream = client.makeRequest(expectedHeaders);
    cStream.sendData(chunk, endStream: true);

    bool isFirst = true;
    cStream.incomingMessages.listen(expectAsync((StreamMessage msg) {
      if (isFirst) {
        expect(msg, new isInstanceOf<DataStreamMessage>());
        final data = msg as DataStreamMessage;
        expect(data.bytes, [2]);
        isFirst = false;
      } else {
        expect(msg, new isInstanceOf<HeadersStreamMessage>());
        final trailer = msg as HeadersStreamMessage;
        expect(trailer.endStream, true);
        expectHeadersEqual(trailer.headers, expectedHeaders);
      }
    }, count: 2));
  });
}
