[![pub package](https://img.shields.io/pub/v/web_socket.svg)](https://pub.dev/packages/web_socket)
[![package publisher](https://img.shields.io/pub/publisher/web_socket.svg)](https://pub.dev/packages/web_socket/publisher)

An easy-to-use library for communicating with
[WebSockets](https://en.wikipedia.org/wiki/WebSocket) that has multiple
implementations.

## Why another WebSocket package?

The goal of `package:web_socket` is to provide a simple, well-defined 
[WebSockets](https://en.wikipedia.org/wiki/WebSocket) interface that has
consistent behavior across implementations.

[`package:web_socket_channel`](https://pub.dev/documentation/web_socket_channel/)
is the most popular WebSocket package but it is complex and does not have
consistent behavior across implementations.

[`WebSocket`](https://pub.dev/documentation/web_socket/latest/web_socket/WebSocket-class.html)
currently has four implementations that all pass the same set of
[conformance tests](https://github.com/dart-lang/http/tree/master/pkgs/web_socket_conformance_tests):

* [`BrowserWebSocket`](https://pub.dev/documentation/web_socket/latest/browser_web_socket/BrowserWebSocket-class.html)
* [`CupertinoWebSocket`](https://pub.dev/documentation/cupertino_http/latest/cupertino_http/CupertinoWebSocket-class.html)
* [`IOWebSocket`](https://pub.dev/documentation/web_socket/latest/io_web_socket/IOWebSocket-class.html)
* [`OkHttpWebSocket`](https://pub.dev/documentation/ok_http/latest/ok_http/OkHttpWebSocket-class.html)
  (currently experimental)

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
