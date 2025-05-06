## 1.0.1

- Fix a bug where `WebSocketException`/`WebSocketConnectionClosed` did not
  have a useful string representation.

## 1.0.0

- First non-experimental release; no semantic changes from version `0.1.6`.

## 0.1.6

- Allow `web: '>=0.5.0 <2.0.0'`.

## 0.1.5

- Allow `1000` as a close code.

## 0.1.4

- Add a `fakes` function that returns a pair of `WebSocket`s useful in
  testing.

## 0.1.3

- Bring the behavior in line with the documentation by throwing
  `WebSocketConnectionClosed` rather `StateError` when attempting to send
  data to or close an already closed `WebSocket`.

## 0.1.2

- Fix a `StateError` in `IOWebSocket` when data is received from the peer
  after the connection has been closed locally.

## 0.1.1

- Add the ability to create a `package:web_socket` `WebSocket` given a
  `dart:io` `WebSocket`.

## 0.1.0

- Basic functionality in place.
