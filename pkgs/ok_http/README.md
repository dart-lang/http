[![pub package](https://img.shields.io/pub/v/ok_http.svg)](https://pub.dev/packages/ok_http)
[![package publisher](https://img.shields.io/pub/publisher/ok_http.svg)](https://pub.dev/packages/ok_http/publisher)

An Android Flutter plugin that provides access to the
[OkHttp][] HTTP client and the OkHttp [WebSocket][] API.

## Why use `package:ok_http`?

### 👍 Increased compatibility and reduced disk profile

`package:ok_http` is smaller and works on more devices than other packages.

This size of the [example application][] APK file using different packages:

| Package | APK Size (MiB) |
|-|-|
| **`ok_http`** | **20.3**  |
| [`cronet_http`](https://pub.dev/packages/cronet_http) [^1] | 20.6 |
| [`cronet_http` (embedded)](https://pub.dev/packages/cronet_http#use-embedded-cronet) [^2] | 34.4 |
| `dart:io` [^3] | 20.4 |

[^1]: Requires [Google Play Services][], which are not available on all devices.
[^2]: Embeds the Cronet HTTP library.
[^3]: Accessed through [`IOClient`](https://pub.dev/documentation/http/latest/io_client/IOClient-class.html).

### 🔌 Supports WebSockets out of the box

`package:ok_http` wraps the OkHttp [WebSocket][] API which supports:

- Configured System Proxy on Android
- HTTP/2

**Example Usage of `OkHttpWebSocket`:**

```dart
import 'package:ok_http/ok_http.dart';
import 'package:web_socket/web_socket.dart';
void main() async {
  final socket = await OkHttpWebSocket.connect(
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

[example application]: https://github.com/dart-lang/http/tree/master/pkgs/flutter_http_example
[OkHttp]: https://square.github.io/okhttp/
[Google Play Services]: https://developers.google.com/android/guides/overview
[WebSocket]: https://square.github.io/okhttp/5.x/okhttp/okhttp3/-web-socket/index.html
