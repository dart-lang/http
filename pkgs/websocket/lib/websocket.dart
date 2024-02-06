import 'dart:async';
import 'dart:typed_data';

/// An event received from the peer through the [XXXWebSocket].
sealed class WebSocketEvent {}

/// Text data received from the peer through the [XXXWebSocket].
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

/// Binary data received from the peer through the [XXXWebSocket].
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

/// A close notification (Close frame) received from the peer through the
/// [XXXWebSocket] or a failure indication.
///
/// See [XXXWebSocket.events].
final class CloseReceived extends WebSocketEvent {
  /// A numerical code indicating the reason why the WebSocket was closed.
  ///
  /// See [RFC-6455 7.4](https://www.rfc-editor.org/rfc/rfc6455.html#section-7.4)
  /// for guidance on how to interpret these codes.
  final int? code;

  /// A textual explanation of the reason why the WebSocket was closed.
  ///
  /// Will be empty if the peer did not specify a reason.
  final String reason;

  CloseReceived([this.code, this.reason = ""]);

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

/// Thrown if [XXXWebSocket.sendText], [XXXWebSocket.sendBytes], or
/// [XXXWebSocket.closed] is called when the [XXXWebSocket] is closed.
class XXXWebSocketConnectionClosed extends XXXWebSocketException {
  XXXWebSocketConnectionClosed([super.message = 'Connection Closed']);
}

/// The interface for WebSocket connections.
///
/// TODO: insert a usage example.
///
/// TODO: thank of a better name, ideally not "WebSocket". Maybe
/// "SimpleWebSocket"?
abstract interface class XXXWebSocket {
  /// Sends text data to the connected peer.
  ///
  /// Throws [XXXWebSocketConnectionClosed] if the [XXXWebSocket] is closed
  /// (either through [close] or by the peer).
  void sendText(String s);

  /// Sends binary data to the connected peer.
  ///
  /// Throws [XXXWebSocketConnectionClosed] if the [XXXWebSocket] is closed
  /// (either through [close] or by the peer).
  void sendBytes(Uint8List b);

  /// Closes the WebSocket connection and the [events] `Stream`.
  ///
  /// Sends a Close frame to the peer. If the optional [code] and [reason]
  /// arguments are given, they will be included in the Close frame. If no
  /// [code] is set then the peer will see a 1005 status code. If no [reason]
  /// is set then the peer will receive an empty reason string.
  ///
  /// Throws a [RangeError] if [code] is not in the range 3000-4999.
  ///
  /// Throws an [ArgumentError] if [reason] is longer than 123 bytes when
  /// encoded as UTF-8
  ///
  /// Throws [XXXWebSocketConnectionClosed] if the connection is already closed
  /// (including by the peer).
  Future<void> close([int? code, String reason = '']);

  /// A [Stream] of [WebSocketEvent] received from the peer.
  ///
  /// Data received by the peer will be delivered as a [TextDataReceived] or
  /// [BinaryDataReceived].
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
  ///
  /// TODO: we can't use a SynchronousStreamController here, right? It would be
  /// cool if we deliver [CloseReceived] **before** the user sees write failures
  /// because [events] is closed.
  Stream<WebSocketEvent> get events;
}
