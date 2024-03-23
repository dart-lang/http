[![pub package](https://img.shields.io/pub/v/web_socket.svg)](https://pub.dev/packages/web_socket)
[![package publisher](https://img.shields.io/pub/publisher/web_socket.svg)](https://pub.dev/packages/web_socket/publisher)

Any easy-to-use library for communicating with WebSockets that has multiple
implementations.

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
