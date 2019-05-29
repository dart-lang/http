# HTTP/2 for Dart

This library provides an http/2 interface on top of a bidirectional stream of bytes.

## Usage:

Here is a minimal example of connecting to a http/2 capable server, requesting a resource and
iterating over the response.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:http2/http2.dart';

main() async {
  var uri = Uri.parse('https://www.google.com/');

  var transport = new ClientTransportConnection.viaSocket(
    await SecureSocket.connect(
      uri.host,
      uri.port,
      supportedProtocols: ['h2'],
    ),
  );

  var stream = transport.makeRequest(
    [
      new Header.ascii(':method', 'GET'),
      new Header.ascii(':path', uri.path),
      new Header.ascii(':scheme', uri.scheme),
      new Header.ascii(':authority', uri.host),
    ],
    endStream: true,
  );

  await for (var message in stream.incomingMessages) {
    if (message is HeadersStreamMessage) {
      for (var header in message.headers) {
        var name = utf8.decode(header.name);
        var value = utf8.decode(header.value);
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
[example]: https://github.com/dart-lang/http2/blob/master/example/display_headers.dart.
