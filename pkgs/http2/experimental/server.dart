// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http2/src/testing/debug.dart' hide print;
import 'package:http2/transport.dart';
import 'package:pedantic/pedantic.dart';

const bool DEBUGGING = false;

const String HOSTNAME = 'localhost';
const int PORT = 7777;

void main() async {
  String localFile(String path) => Platform.script.resolve(path).toFilePath();

  var context = SecurityContext()
    ..usePrivateKey(localFile('server_key.pem'), password: 'dartdart')
    ..useCertificateChain(localFile('server_chain.pem'))
    ..setAlpnProtocols(['h2'], true);

  var server = await SecureServerSocket.bind(HOSTNAME, PORT, context);
  print('HTTP/2 server listening on https://$HOSTNAME:$PORT');

  runZoned(() {
    server.listen(handleClient);
  }, onError: (e, s) {
    print('Unexpected error: $e');
    print('Unexpected error - stack: $s');
  });
}

void handleClient(SecureSocket socket) {
  dumpInfo('main', 'Got new https client');

  var connection;
  if (DEBUGGING) {
    connection = debugPrintingConnection(socket);
  } else {
    connection = ServerTransportConnection.viaSocket(socket);
  }

  connection.incomingStreams.listen((ServerTransportStream stream) async {
    dumpInfo('main', 'Got new HTTP/2 stream with id: ${stream.id}');

    String path;
    stream.incomingMessages.listen((StreamMessage msg) async {
      dumpInfo('${stream.id}', 'Got new incoming message');
      if (msg is HeadersStreamMessage) {
        dumpHeaders('${stream.id}', msg.headers);
        if (path == null) {
          path = pathFromHeaders(msg.headers);
          if (path == null) throw Exception('no path given');

          if (path == '/') {
            unawaited(sendHtml(stream));
          } else if (['/iframe', '/iframe2'].contains(path)) {
            unawaited(sendIFrameHtml(stream, path));
          } else {
            unawaited(send404(stream, path));
          }
        }
      } else if (msg is DataStreamMessage) {
        dumpData('${stream.id}', msg.bytes);
      }
    });
  });
}

void dumpHeaders(String prefix, List<Header> headers) {
  for (var i = 0; i < headers.length; i++) {
    var key = ascii.decode(headers[i].name);
    var value = ascii.decode(headers[i].value);
    print('[$prefix] $key: $value');
  }
}

String pathFromHeaders(List<Header> headers) {
  for (var i = 0; i < headers.length; i++) {
    if (ascii.decode(headers[i].name) == ':path') {
      return ascii.decode(headers[i].value);
    }
  }
  throw Exception('Expected a :path header, but did not find one.');
}

void dumpData(String prefix, List<int> data) {
  print('[$prefix] Got ${data.length} bytes.');
}

void dumpInfo(String prefix, String msg) {
  print('[$prefix] $msg');
}

Future sendHtml(ServerTransportStream stream) async {
  unawaited(push(stream, '/iframe', sendIFrameHtml));
  unawaited(push(stream, '/iframe2', sendIFrameHtml));
  unawaited(push(stream, '/favicon.ico', send404));

  stream.sendHeaders([
    Header.ascii(':status', '200'),
    Header.ascii('content-type', 'text/html; charset=utf-8'),
  ]);
  stream.sendData(ascii.encode('''
<html>
  <head><title>hello</title></head>
  <body>
    <h1> head </h1>
    first <br />
    <iframe src='/iframe' with="100" height="100"></iframe> <br />
    second <br />
    <iframe src='/iframe2' with="100" height="100"></iframe> <br />
  </body>
</html>
'''));
  return stream.outgoingMessages.close();
}

Future push(ServerTransportStream stream, String path,
    Future Function(TransportStream, String path) sendResponse) async {
  var requestHeaders = [
    Header.ascii(':authority', '$HOSTNAME:$PORT'),
    Header.ascii(':method', 'GET'),
    Header.ascii(':path', path),
    Header.ascii(':scheme', 'https'),
  ];

  var pushStream = stream.push(requestHeaders);
  await sendResponse(pushStream, path);
}

Future sendIFrameHtml(TransportStream stream, String path) async {
  stream.sendHeaders([
    Header.ascii(':status', '200'),
    Header.ascii('content-type', 'text/html; charset=utf-8'),
  ]);
  stream.sendData(ascii.encode('''
<html>
  <head><title>Content for '$path' inside an IFrame.</title></head>
  <body>
    <h2>Content for '$path' inside an IFrame.</h2>
  </body>
</html>
'''));
  await stream.outgoingMessages.close();
}

Future send404(TransportStream stream, String path) async {
  stream.sendHeaders([
    Header.ascii(':status', '404'),
    Header.ascii('content-type', 'text/html; charset=utf-8'),
  ]);
  stream.sendData(ascii.encode('''
<html>
  <head><title>Path '$path' was not found on this server.</title></head>
  <body>
    <h1>Path '$path' was not found on this server.</h1>
  </body>
</html>
'''));
  return stream.outgoingMessages.close();
}
