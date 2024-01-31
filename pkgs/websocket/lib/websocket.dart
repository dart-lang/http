import 'dart:async';
import 'dart:typed_data';

sealed class WebSocketEvent {}

/// Text data received by the peer.
///
/// See [XXXWebSocket.events].
final class TextDataReceived extends WebSocketEvent {
  final String text;
  TextDataReceived(this.text);

  @override
  bool operator ==(Object other) =>
      other is TextDataReceived && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// Binary data received by the peer.
///
/// See [XXXWebSocket.events].
final class BinaryDataReceived extends WebSocketEvent {
  final Uint8List data;
  BinaryDataReceived(this.data);

  @override
  bool operator ==(Object other) {
    if (other is BinaryDataReceived && other.data.length == data.length) {
      for (var i = 0; i < data.length; ++i) {
        if (other.data[i] != data[i]) return false;
      }
      return true;
    }
    return false;
  }

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'BinaryDataReceived($data)';
}

/// A close notification sent from the peer or a failure indication.
///
/// See [XXXWebSocket.events].
final class CloseReceived extends WebSocketEvent {
  /// See [RFC-6455 7.4](https://www.rfc-editor.org/rfc/rfc6455.html#section-7.4)
  final int? code;
  final String? reason;

  CloseReceived([this.code, this.reason]);

  @override
  bool operator ==(Object other) =>
      other is CloseReceived && other.code == code && other.reason == reason;

  @override
  int get hashCode => [code, reason].hashCode;

  @override
  String toString() => 'CloseReceived($code, $reason)';
}

class XXXWebSocketException implements Exception {
  final String message;
  XXXWebSocketException([this.message = ""]);
}

/// Thrown if [XXXWebSocket.sendText] or [XXXWebSocket.sendBytes] is called
/// when the [XXXWebSocket] is closed.
class XXXWebSocketConnectionClosed extends XXXWebSocketException {
  XXXWebSocketConnectionClosed([super.message = 'Connection Closed']);
}

/// What's a good name for this? `SimpleWebSocket`? 'LCDWebSocket`?
abstract interface class XXXWebSocket {
  /// Say something about not guaranteeing delivery.
  ///
  /// Throws [XXXWebSocketConnectionClosed] if the [XXXWebSocket] is closed
  /// (either through [close] or by the peer). Alternatively, we could just throw
  /// the data away - that's what JavaScript does. Probably that is better
  /// so every call to [sendText], [sendBytes] and [close] doesn't need to be
  /// surrounded in a try block.
  void sendText(String s);

  /// Say something about not guaranteeing delivery.
  ///
  /// Throws [XXXWebSocketConnectionClosed] if the [XXXWebSocket] is closed
  /// (either through [close] or by the peer). Alternatively, we could just throw
  /// the data away - that's what JavaScript does.
  void sendBytes(Uint8List b);

  /// Closes the WebSocket connection.
  ///
  /// Set the optional code and reason arguments to send close information
  /// to the peer. If they are omitted, the peer will see a 1005 status code
  /// with no reason.
  ///
  /// If [code] is not in the range 3000-4999 then an [ArgumentError]
  /// will be thrown.
  ///
  /// If [reason] is longer than 123 bytes when encoded as UTF-8 then
  /// [ArgumentError] will be thrown.
  ///
  /// [events] will be closed.
  ///
  /// Throws [XXXWebSocketConnectionClosed] if the connection is already closed
  /// (including by the peer). Alternatively, we could just throw the close
  /// away.
  Future<void> close([int? code, String? reason]);

  /// Events received from the peer.
  ///
  /// If a [CloseReceived] event is received then the [Stream] will be closed. A
  /// [CloseReceived] event indicates either that:
  ///
  /// - A close frame was received from the peer. [CloseReceived.code] and
  ///   [CloseReceived.reason] will be set by the peer.
  /// - A failure occured (e.g. the peer disconnected). [CloseReceived.code] and
  ///   [CloseReceived.reason] will be a failure code defined by
  ///   (RFC-6455)[https://www.rfc-editor.org/rfc/rfc6455.html#section-7.4.1]
  ///   (e.g. 1006).
  ///
  /// Errors will never appear in this [Stream].
  Stream<WebSocketEvent> get events;
}
