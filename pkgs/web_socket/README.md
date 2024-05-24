[![pub package](https://img.shields.io/pub/v/web_socket.svg)](https://pub.dev/packages/web_socket)
[![package publisher](https://img.shields.io/pub/publisher/web_socket.svg)](https://pub.dev/packages/web_socket/publisher)

Any easy-to-use library for communicating with
[WebSockets](https://en.wikipedia.org/wiki/WebSocket) that has multiple
implementations.

## Why another WebSocket package?

The goal of `package:web_socket` is to provide a simple, well-defined 
[WebSockets](https://en.wikipedia.org/wiki/WebSocket) interface that has
consistent behavior across implementations.

[`package:web_socket_channel`](https://pub.dev/documentation/web_socket_channel/)
is currently the most popular WebSocket package. It has
two implementations, one based on `package:web` and the other based on
`dart:io` `WebSocket`. But those implementations do not have consistent
behavior.

[`WebSocket`](https://pub.dev/documentation/web_socket/latest/web_socket/WebSocket-class.html)
currently has three implementations (with more on the way) that
all pass the same set of
[conformance tests](https://github.com/dart-lang/http/tree/master/pkgs/web_socket_conformance_tests):

* [`BrowserWebSocket`](https://pub.dev/documentation/web_socket/latest/browser_web_socket/BrowserWebSocket-class.html)
* [`CupertinoWebSocket`](https://pub.dev/documentation/cupertino_http/latest/cupertino_http/CupertinoWebSocket-class.html)
* [`IOWebSocket`](https://pub.dev/documentation/web_socket/latest/io_web_socket/IOWebSocket-class.html)

## Using

```dart
import 'package:web_socket/web_socket.dart';

void main() async {
  final socket =
      await WebSocket.connect(Uri.parse('wss://ws.postman-echo.com/raw'));

  socket.events.listen((e) async {
    switch (e) {
      case TextDataReceived(text: final text):
        print('Received Text: $text');
        await socket.close();
      case BinaryDataReceived(data: final data):
        print('Received Binary: $data');
      case CloseReceived(code: final code, reason: final reason):
        print('Connection to server closed: $code [$reason]');
    }
  });

  socket.sendText('Hello Dart WebSockets! 🎉');
}
```

## Status: experimental

**NOTE**: This package is currently experimental and published under the
[labs.dart.dev](https://dart.dev/dart-team-packages) pub publisher in order to
solicit feedback.

For packages in the labs.dart.dev publisher we generally plan to either graduate
the package into a supported publisher (dart.dev, tools.dart.dev) after a period
of feedback and iteration, or discontinue the package. These packages have a
much higher expected rate of API and breaking changes.

Your feedback is valuable and will help us evolve this package. For general
feedback, suggestions, and comments, please file an issue in the
[bug tracker](https://github.com/dart-lang/http/issues).
