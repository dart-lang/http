import 'dart:async';
import 'dart:typed_data';

sealed class WebSocketEvent {}

class TextDataReceived extends WebSocketEvent {
  final String text;
  TextDataReceived(this.text);

  @override
  bool operator ==(Object other) =>
      other is TextDataReceived && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

class BinaryDataReceived extends WebSocketEvent {
  final Uint8List data;
  BinaryDataReceived(this.data);

  // XXX
  @override
  bool operator ==(Object other) =>
      other is BinaryDataReceived && other.data.length == data.length;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'BinaryDataReceived($data)';
}

class Closed extends WebSocketEvent {
  final int? code;
  final String? reason;

  Closed([this.code, this.reason]);

  @override
  bool operator ==(Object other) =>
      other is Closed && other.code == code && other.reason == reason;

  @override
  int get hashCode => [code, reason].hashCode;

  @override
  String toString() => 'Closed($code, $reason)';
}

class XXXWebSocketException implements Exception {
  final String message;
  XXXWebSocketException([this.message = ""]);
}

class WebSocketConnectionClosed extends XXXWebSocketException {
  WebSocketConnectionClosed([super.message = 'Connection Closed']);
}

abstract interface class WebSocket {
  /// Throws [WebSocketConnectionClosed] if the [WebSocket] is closed (either through [close] or by the peer).
  void addString(String s);

  /// Throws [WebSocketConnectionClosed] if the [WebSocket] is closed (either through [close] or by the peer).
  void addBytes(Uint8List b);

  /// Closes the WebSocket connection.
  ///
  /// Set the optional code and reason arguments to send close information
  /// to the peer. If they are omitted, the peer will see a 1005 status code
  /// with no reason.
  ///
  /// [events] will be closed.
  Future<void> close([int? code, String? reason]);

  /// Events received from the peer.
  ///
  /// If a [Closed] event is received then the [Stream] will be closed. A
  /// [Closed] event indicates either that:
  ///
  /// - A close frame was received from the peer. [Closed.code] and
  ///   [Closed.reason] will be set by the peer.
  /// - A failure occured (e.g. the peer disconnected). [Closed.code] and
  ///   [Closed.reason] will be a failure code defined by
  ///   (RFC-6455)[https://www.rfc-editor.org/rfc/rfc6455.html#section-7.4.1]
  ///   (e.g. 1006).
  ///
  /// Errors will never appear in this [Stream].
  Stream<WebSocketEvent> get events;
}
