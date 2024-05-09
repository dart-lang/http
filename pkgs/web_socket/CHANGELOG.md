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
