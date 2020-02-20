import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http2/transport.dart';

void main(List<String> args) async {
  if (args == null || args.length != 1) {
    print('Usage: dart display_headers.dart <HTTPS_URI>');
    exit(1);
  }

  var uriArg = args[0];

  if (!uriArg.startsWith('https://')) {
    print('URI must start with https://');
    exit(1);
  }

  var uri = Uri.parse(uriArg);

  var socket = await connect(uri);

  // The default client settings will disable server pushes. We
  // therefore do not need to deal with [stream.peerPushes].
  var transport = ClientTransportConnection.viaSocket(socket);

  var headers = [
    Header.ascii(':method', 'GET'),
    Header.ascii(':path', uri.path),
    Header.ascii(':scheme', uri.scheme),
    Header.ascii(':authority', uri.host),
  ];

  var stream = transport.makeRequest(headers, endStream: true);
  await for (var message in stream.incomingMessages) {
    if (message is HeadersStreamMessage) {
      for (var header in message.headers) {
        var name = utf8.decode(header.name);
        var value = utf8.decode(header.value);
        print('$name: $value');
      }
    } else if (message is DataStreamMessage) {
      // Use [message.bytes] (but respect 'content-encoding' header)
    }
  }
  await transport.finish();
}

Future<Socket> connect(Uri uri) async {
  var useSSL = uri.scheme == 'https';
  if (useSSL) {
    var secureSocket = await SecureSocket.connect(uri.host, uri.port,
        supportedProtocols: ['h2']);
    if (secureSocket.selectedProtocol != 'h2') {
      throw Exception('Failed to negogiate http/2 via alpn. Maybe server '
          "doesn't support http/2.");
    }
    return secureSocket;
  } else {
    return await Socket.connect(uri.host, uri.port);
  }
}
