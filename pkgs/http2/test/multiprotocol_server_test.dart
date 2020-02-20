// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show ascii, utf8;
import 'dart:io';

import 'package:test/test.dart';

import 'package:http2/transport.dart';
import 'package:http2/multiprotocol_server.dart';

void main() {
  var context = SecurityContext()
    ..useCertificateChain('test/certificates/server_chain.pem')
    ..usePrivateKey('test/certificates/server_key.pem', password: 'dartdart');

  group('multiprotocol-server', () {
    test('http/1.1', () async {
      const Count = 2;

      var server = await MultiProtocolHttpServer.bind('localhost', 0, context);
      var requestNr = 0;
      server.startServing(
          expectAsync1((HttpRequest request) async {
            await handleHttp11Request(request, requestNr++);
            if (requestNr == Count) {
              await server.close();
            }
          }, count: Count),
          expectAsync1((ServerTransportStream stream) {}, count: 0));

      var client = HttpClient();
      client.badCertificateCallback = (_, __, ___) => true;
      for (var i = 0; i < Count; i++) {
        await makeHttp11Request(server, client, i);
      }
    });

    test('http/2', () async {
      const Count = 2;

      var server = await MultiProtocolHttpServer.bind('localhost', 0, context);
      var requestNr = 0;
      server.startServing(
          expectAsync1((HttpRequest request) {}, count: 0),
          expectAsync1((ServerTransportStream stream) async {
            await handleHttp2Request(stream, requestNr++);
            if (requestNr == Count) {
              await server.close();
            }
          }, count: Count));

      var socket = await SecureSocket.connect('localhost', server.port,
          onBadCertificate: (_) => true,
          supportedProtocols: ['http/1.1', 'h2']);
      var connection = ClientTransportConnection.viaSocket(socket);
      for (var i = 0; i < Count; i++) {
        await makeHttp2Request(server, connection, i);
      }
      await connection.finish();
    });
  });
}

Future makeHttp11Request(
    MultiProtocolHttpServer server, HttpClient client, int i) async {
  var request =
      await client.getUrl(Uri.parse('https://localhost:${server.port}/abc$i'));
  var response = await request.close();
  var body = await response.cast<List<int>>().transform(utf8.decoder).join('');
  expect(body, 'answer$i');
}

Future handleHttp11Request(HttpRequest request, int i) async {
  expect(request.uri.path, '/abc$i');
  await request.drain();
  request.response.write('answer$i');
  await request.response.close();
}

Future makeHttp2Request(MultiProtocolHttpServer server,
    ClientTransportConnection connection, int i) async {
  expect(connection.isOpen, true);
  var headers = [
    Header.ascii(':method', 'GET'),
    Header.ascii(':scheme', 'https'),
    Header.ascii(':authority', 'localhost:${server.port}'),
    Header.ascii(':path', '/abc$i'),
  ];

  var stream = connection.makeRequest(headers, endStream: true);
  var si = StreamIterator(stream.incomingMessages);

  expect(await si.moveNext(), true);
  expect(si.current, isA<HeadersStreamMessage>());
  var responseHeaders = getHeaders(si.current as HeadersStreamMessage);
  expect(responseHeaders[':status'], '200');

  expect(await si.moveNext(), true);
  expect(ascii.decode((si.current as DataStreamMessage).bytes), 'answer$i');

  expect(await si.moveNext(), false);
}

Future handleHttp2Request(ServerTransportStream stream, int i) async {
  var si = StreamIterator(stream.incomingMessages);

  expect(await si.moveNext(), true);
  expect(si.current, isA<HeadersStreamMessage>());
  var headers = getHeaders(si.current as HeadersStreamMessage);

  expect(headers[':path'], '/abc$i');
  expect(await si.moveNext(), false);

  stream.outgoingMessages.add(HeadersStreamMessage([
    Header.ascii(':status', '200'),
  ]));

  stream.outgoingMessages.add(DataStreamMessage(ascii.encode('answer$i')));
  await stream.outgoingMessages.close();
}

Map<String, String> getHeaders(HeadersStreamMessage headers) {
  var map = <String, String>{};
  for (var h in headers.headers) {
    map.putIfAbsent(ascii.decode(h.name), () => ascii.decode(h.value));
  }
  return map;
}
