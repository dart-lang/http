[![Dart CI](https://github.com/dart-lang/http2/actions/workflows/test-package.yml/badge.svg)](https://github.com/dart-lang/http2/actions/workflows/test-package.yml)
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

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/dart-lang/http2/issues
[api]: https://pub.dev/documentation/http2/latest/
[example]: https://github.com/dart-lang/http2/blob/master/example/display_headers.dart
