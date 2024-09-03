[![pub package](https://img.shields.io/pub/v/cupertino_http.svg)](https://pub.dev/packages/cupertino_http)
[![package publisher](https://img.shields.io/pub/publisher/cupertino_http.svg)](https://pub.dev/packages/cupertino_http/publisher)

A macOS/iOS Flutter plugin that provides access to the
[Foundation URL Loading System][].

## Motivation

Using the [Foundation URL Loading System][], rather than the socket-based
[dart:io HttpClient][] implementation, has several advantages:

1. It automatically supports iOS/macOS platform features such VPNs and HTTP
   proxies. 
2. It supports many more configuration options such as only allowing access
   through WiFi and blocking cookies.
3. It supports more HTTP features such as HTTP/3 and custom redirect handling.

## Using

The easiest way to use this library is via the high-level interface
defined by [package:http Client][].

This approach allows the same HTTP code to be used on all platforms, while
still allowing platform-specific setup.

```dart
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

void main() async {
  final Client httpClient;
  if (Platform.isIOS || Platform.isMacOS) {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration()
      ..cache = URLCache.withCapacity(memoryCapacity: 2 * 1024 * 1024)
      ..httpAdditionalHeaders = {'User-Agent': 'Book Agent'};
    httpClient = CupertinoClient.fromSessionConfiguration(config);
  } else {
    httpClient = IOClient(HttpClient()..userAgent = 'Book Agent');
  }

  final response = await client.get(Uri.https(
      'www.googleapis.com',
      '/books/v1/volumes',
      {'q': 'HTTP', 'maxResults': '40', 'printType': 'books'}));
}
```

[CupertinoWebSocket][] provides a [package:web_socket][] [WebSocket][]
implementation.

```dart
import 'package:cupertino_http/cupertino_http.dart';
import 'package:web_socket/web_socket.dart';

void main() async {
  final socket = await CupertinoWebSocket.connect(
      Uri.parse('wss://ws.postman-echo.com/raw'));

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
}
```

You can also use the [Foundation URL Loading System] API directly.

```dart
final url = Uri.https(
    'www.googleapis.com',
    '/books/v1/volumes',
    {'q': 'HTTP', 'maxResults': '40', 'printType': 'books'});
final session = URLSession.sharedSession();
final task = session.dataTaskWithCompletionHandler(URLRequest.fromUrl(url),
    (data, response, error) {
  if (error == null && response!.statusCode == 200) {
    print(data!.bytes);
  }
});
task.resume();
```

[CupertinoWebSocket]: https://pub.dev/documentation/cupertino_http/latest/cupertino_http/CupertinoWebSocket-class.html
[dart:io HttpClient]: https://api.dart.dev/stable/dart-io/HttpClient-class.html
[Foundation URL Loading System]: https://developer.apple.com/documentation/foundation/url_loading_system
[package:http Client]: https://pub.dev/documentation/http/latest/http/Client-class.html
[package:web_socket]: https://pub.dev/packages/web_socket
[WebSocket]: https://pub.dev/documentation/web_socket/latest/web_socket/WebSocket-class.html
