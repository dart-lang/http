import 'dart:typed_data';

/// An event received from the peer through the [WebSocket].
sealed class WebSocketEvent {}

/// Text data received from the peer through the [WebSocket].
///
/// See [WebSocket.events].
final class TextDataReceived extends WebSocketEvent {
  final String text;
  TextDataReceived(this.text);

  @override
  bool operator ==(Object other) =>
      other is TextDataReceived && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// Binary data received from the peer through the [WebSocket].
///
/// See [WebSocket.events].
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
/// [WebSocket] or a failure indication.
///
/// See [WebSocket.events].
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

  CloseReceived([this.code, this.reason = '']);

  @override
  bool operator ==(Object other) =>
      other is CloseReceived && other.code == code && other.reason == reason;

  @override
  int get hashCode => [code, reason].hashCode;

  @override
  String toString() => 'CloseReceived($code, $reason)';
}

class WebSocketException implements Exception {
  final String message;
  WebSocketException([this.message = '']);
}

/// Thrown if [WebSocket.sendText], [WebSocket.sendBytes], or
/// [WebSocket.close] is called when the [WebSocket] is closed.
class WebSocketConnectionClosed extends WebSocketException {
  WebSocketConnectionClosed([super.message = 'Connection Closed']);
}

/// The interface for WebSocket connections.
///
/// TODO: insert a usage example.
abstract interface class WebSocket {
  /// Sends text data to the connected peer.
  ///
  /// Throws [WebSocketConnectionClosed] if the [WebSocket] is
  /// closed (either through [close] or by the peer).
  ///
  /// Data sent through [sendText] will be silently discarded if the peer is
  /// disconnected but the disconnect has not yet been detected.
  void sendText(String s);

  /// Sends binary data to the connected peer.
  ///
  /// Throws [WebSocketConnectionClosed] if the [WebSocket] is
  /// closed (either through [close] or by the peer).
  ///
  /// Data sent through [sendBytes] will be silently discarded if the peer is
  /// disconnected but the disconnect has not yet been detected.
  void sendBytes(Uint8List b);

  /// Closes the WebSocket connection and the [events] `Stream`.
  ///
  /// Sends a Close frame to the peer. If the optional [code] and [reason]
  /// arguments are given, they will be included in the Close frame. If no
  /// [code] is set then the peer will see a 1005 status code. If no [reason]
  /// is set then the peer will not receive a reason string.
  ///
  /// Throws a [RangeError] if [code] is not in the range 3000-4999.
  ///
  /// Throws an [ArgumentError] if [reason] is longer than 123 bytes when
  /// encoded as UTF-8
  ///
  /// Throws [WebSocketConnectionClosed] if the connection is already
  /// closed (including by the peer).
  Future<void> close([int? code, String? reason]);

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
  Stream<WebSocketEvent> get events;
}
