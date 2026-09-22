[![pub package](https://img.shields.io/pub/v/http2.svg)](https://pub.dev/packages/http2)
[![package publisher](https://img.shields.io/pub/publisher/http2.svg)](https://pub.dev/packages/http2/publisher)

This library provides an http/2 interface on top of a bidirectional stream of bytes.

## Usage

Here is a minimal example of connecting to a http/2 capable server, requesting
a resource and iterating over the response.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:http2/http2.dart';

Future<void> main() async {
  final uri = Uri.parse('https://www.google.com/');

  final transport = ClientTransportConnection.viaSocket(
    await SecureSocket.connect(
      uri.host,
      uri.port,
      supportedProtocols: ['h2'],
    ),
  );

  final stream = transport.makeRequest(
    [
      Header.ascii(':method', 'GET'),
      Header.ascii(':path', uri.path),
      Header.ascii(':scheme', uri.scheme),
      Header.ascii(':authority', uri.host),
    ],
    endStream: true,
  );

  await for (var message in stream.incomingMessages) {
    if (message is HeadersStreamMessage) {
      for (var header in message.headers) {
        final name = utf8.decode(header.name);
        final value = utf8.decode(header.value);
        print('Header: $name: $value');
      }
    } else if (message is DataStreamMessage) {
      // Use [message.bytes] (but respect 'content-encoding' header)
    }
  }
  await transport.finish();
}
```

An example with better error handling is available [here][example].

See the [API docs][api] for more details.

## Pooled `http.Client`

`package:http2/client.dart` provides `Http2Client`, a `package:http`
`Client` that pools and multiplexes requests over shared HTTP/2 connections
instead of opening one connection per request. This is useful for workloads
that send many concurrent requests to the same host or hosts, where
`dart:io`'s `HttpClient` (HTTP/1.1 only) would otherwise open a new TCP+TLS
connection per request.

```dart
import 'package:http2/client.dart';

Future<void> main() async {
  final client = Http2Client();
  final response = await client.get(Uri.parse('https://example.com/'));
  print(response.body);
  client.close();
}
```

A connection is dialed per `host:port` as needed, so a single `Http2Client`
is safe to reuse across requests to different hosts. Note that it speaks only
HTTP/2 and does not fall back to HTTP/1.1: a server that does not negotiate
`h2` is treated as an error. See the example
[here](example/main.dart).
