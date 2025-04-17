## 3.0.3

- Support `package:web_socket` 1.0.0.

## 3.0.2

- Move to `dart-lang/http` monorepo.

## 3.0.1

- Remove unnecessary `dependency_overrides`.
- Remove obsolete documentation for `WebSocketChannel.new`.
- Update package `web: '>=0.5.0 <2.0.0'`.

## 3.0.0

- Provide an adapter around `package:web_socket` `WebSocket`s and make it the
  default implementation for `WebSocketChannel.connect`.
- **BREAKING**: Remove `WebSocketChannel` constructor.
- **BREAKING**: Make `WebSocketChannel` an `abstract interface`.
- **BREAKING**: `IOWebSocketChannel.ready` will throw
  `WebSocketChannelException` instead of `WebSocketException`.

## 2.4.5

- use secure random number generator for frame masking.

## 2.4.4

- Require Dart `^3.3`
- Require `package:web` `^0.5.0`.

## 2.4.3

- `HtmlWebSocketChannel`: Relax the type of the websocket parameter to the
  constructor in order to mitigate a breaking change introduced in `2.4.1`.

## 2.4.2 (retracted)

- Allow `web: '>=0.3.0 <0.5.0'`

## 2.4.1

- Update the examples to use `WebSocketChannel.ready` and clarify that
  `WebSocketChannel.ready` should be awaited before sending data over the
  `WebSocketChannel`.
- Mention `ready` in the docs for `connect`.
- Bump minimum Dart version to 3.2.0
- Move to `pkg:web` to support WebAssembly compilation.

## 2.4.0

- Add a `customClient` parameter to the `IOWebSocketChannel.connect` factory,
  which allows the user to provide a custom `HttpClient` instance to use for the
  WebSocket connection
- Bump minimum Dart version to 2.15.0

## 2.3.0

- Added a Future `ready` property to `WebSocketChannel`, which completes when
  the connection is established
- Added a `connectTimeout` parameter to the `IOWebSocketChannel.connect` factory,
  which controls the timeout of the WebSocket Future.
- Use platform agnostic code in README example.

## 2.2.0

- Add `HtmlWebSocketChannel.innerWebSocket` getter to access features not exposed
  through the shared `WebSocketChannel` interface.

## 2.1.0

- Add `IOWebSocketChannel.innerWebSocket` getter to access features not exposed
  through the shared `WebSocketChannel` interface.

## 2.0.0

- Support null safety.
- Require Dart 2.12.

## 1.2.0

* Add `protocols` argument to `WebSocketChannel.connect`. See the docs for
  `WebSocket.connet`.
* Allow the latest crypto release (`3.x`).

## 1.1.0

* Add `WebSocketChannel.connect` factory constructor supporting platform
  independent creation of WebSockets providing the lowest common denominator
  of support on dart:io and dart:html.

## 1.0.15

* bug fix don't pass protocols parameter to WebSocket.

## 1.0.14

* Updates to handle `Socket implements Stream<Uint8List>`

## 1.0.13

* Internal changes for consistency with the Dart SDK.

## 1.0.12

* Allow `stream_channel` version 2.x

## 1.0.11

* Fixed description in pubspec.

* Fixed lints in README.md.

## 1.0.10

* Fixed links in README.md.

* Added an example.

* Fixed analysis lints that affected package score.

## 1.0.9

* Set max SDK version to `<3.0.0`.

## 1.0.8

* Remove use of deprecated constant name.

## 1.0.7

* Support the latest dev SDK.

## 1.0.6

* Declare support for `async` 2.0.0.

## 1.0.5

* Increase the SDK version constraint to `<2.0.0-dev.infinity`.

## 1.0.4

* Support `crypto` 2.0.0.

## 1.0.3

* Fix all strong-mode errors and warnings.

* Fix a bug where `HtmlWebSocketChannel.close()` would crash on non-Dartium
  browsers if the close code and reason weren't provided explicitly.

## 1.0.2

* Properly use `BASE64` from `dart:convert` rather than `crypto`.

## 1.0.1

* Add support for `crypto` 1.0.0.

## 1.0.0

* Initial version
