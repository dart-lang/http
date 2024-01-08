[![CI](https://github.com/dart-lang/web_socket_channel/actions/workflows/test-package.yml/badge.svg?branch=master)](https://github.com/dart-lang/web_socket_channel/actions/workflows/test-package.yml)
[![pub package](https://img.shields.io/pub/v/web_socket_channel.svg)](https://pub.dev/packages/web_socket_channel)
[![package publisher](https://img.shields.io/pub/publisher/web_socket_channel.svg)](https://pub.dev/packages/web_socket_channel/publisher)

`package:web_socket_channel` provides cross-platform
[`StreamChannel`][stream_channel] wrappers for WebSocket connections.

## Docs and Usage

It provides a cross-platform
[`WebSocketChannel`][WebSocketChannel] API, a cross-platform implementation of
that API that communicates over an underlying [`StreamChannel`][stream_channel],
[an implementation][IOWebSocketChannel] that wraps `dart:io`'s `WebSocket`
class, and [a similar implementation][HtmlWebSocketChannel] that wraps
`dart:html`'s.

[stream_channel]: https://pub.dev/packages/stream_channel
[WebSocketChannel]: https://pub.dev/documentation/web_socket_channel/latest/web_socket_channel/WebSocketChannel-class.html
[IOWebSocketChannel]: https://pub.dev/documentation/web_socket_channel/latest/web_socket_channel.io/IOWebSocketChannel-class.html
[HtmlWebSocketChannel]: https://pub.dev/documentation/web_socket_channel/latest/web_socket_channel.html/HtmlWebSocketChannel-class.html

It also provides constants for the WebSocket protocol's pre-defined status codes
in the [`status.dart` library][status]. It's strongly recommended that users
import this library with the prefix `status`.

[status]: https://pub.dev/documentation/web_socket_channel/latest/status/status-library.html

```dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

main() async {
  final wsUrl = Uri.parse('ws://example.com');
  final channel = WebSocketChannel.connect(wsUrl);

  await channel.ready;

  channel.stream.listen((message) {
    channel.sink.add('received!');
    channel.sink.close(status.goingAway);
  });
}
```

## `WebSocketChannel`

The [`WebSocketChannel`][WebSocketChannel] class's most important role is as the
interface for WebSocket stream channels across all implementations and all
platforms. In addition to the base `StreamChannel` interface, it adds a
[`protocol`][protocol] getter that returns the negotiated protocol for the
socket, as well as [`closeCode`][closeCode] and [`closeReason`][closeReason]
getters that provide information about why the socket closed.

[protocol]: https://pub.dev/documentation/web_socket_channel/latest/web_socket_channel/WebSocketChannel/protocol.html
[closeCode]: https://pub.dev/documentation/web_socket_channel/latest/web_socket_channel/WebSocketChannel/closeCode.html
[closeReason]: https://pub.dev/documentation/web_socket_channel/latest/web_socket_channel/WebSocketChannel/closeReason.html

The channel's [`sink` property][sink] is also special. It returns a
[`WebSocketSink`][WebSocketSink], which is just like a `StreamSink` except that
its [`close()`][sink.close] method supports optional `closeCode` and
`closeReason` parameters. These parameters allow the caller to signal to the
other socket exactly why they're closing the connection.

[sink]: https://pub.dev/documentation/web_socket_channel/latest/web_socket_channel/WebSocketChannel/sink.html
[WebSocketSink]: https://pub.dev/documentation/web_socket_channel/latest/web_socket_channel/WebSocketSink-class.html
[sink.close]: https://pub.dev/documentation/web_socket_channel/latest/web_socket_channel/WebSocketSink/close.html

`WebSocketChannel` also works as a cross-platform implementation of the
WebSocket protocol. The [`WebSocketChannel.connect` constructor][connect]
connects to a listening server using the appropriate implementation for the
platform. The [`WebSocketChannel()` constructor][new] takes an underlying
[`StreamChannel`][stream_channel] over which it communicates using the WebSocket
protocol. It also provides the static [`signKey()`][signKey] method to make it
easier to implement the [initial WebSocket handshake][]. These are used in the
[`shelf_web_socket`][shelf_web_socket] package to support WebSockets in a
cross-platform way.

[connect]: https://pub.dev/documentation/web_socket_channel/latest/web_socket_channel/WebSocketChannel/WebSocketChannel.connect.html
[new]: https://pub.dev/documentation/web_socket_channel/latest/web_socket_channel/WebSocketChannel/WebSocketChannel.html
[signKey]: https://pub.dev/documentation/web_socket_channel/latest/web_socket_channel/WebSocketChannel/signKey.html
[initial WebSocket handshake]: https://tools.ietf.org/html/rfc6455#section-4.2.2
[shelf_web_socket]: https://pub.dev/packages/shelf_web_socket
