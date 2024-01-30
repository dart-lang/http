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

abstract interface class WebSocket {
  void addString(String s);
  void addBytes(Uint8List b);
  Future<void> close([int? code, String? reason]);

  /// Will be closed after disconnect. No events will be received after
  /// [Closed]. [Closed] will not appear in [events] if [close] is called.
  Stream<WebSocketEvent> get events;
}
