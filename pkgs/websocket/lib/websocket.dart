import 'dart:async';
import 'dart:typed_data';
import 'dart:io' as io;

import 'package:cupertino_http/cupertino_http.dart';

sealed class WebSocketEvent {}

class TextDataReceived extends WebSocketEvent {
  final String text;
  TextDataReceived(this.text);
}

class BinaryDataReceived extends WebSocketEvent {
  final Uint8List data;
  BinaryDataReceived(this.data);
}

class Closed extends WebSocketEvent {
  final int? code;
  final String? reason;

  Closed([this.code, this.reason]);
}

abstract interface class WebSocket {
  void addString(String s);
  void addBytes(Uint8List b);
  Future<void> close([int? code, String? reason]);
  Stream<WebSocketEvent> get events;
}

class IOWebSocket implements WebSocket {
  final io.WebSocket _webSocket;
  final _events = StreamController<WebSocketEvent>();

  static Future<IOWebSocket> connect(Uri uri) async {
    final webSocket = await io.WebSocket.connect(uri.toString());
    return IOWebSocket._(webSocket);
  }

  IOWebSocket._(this._webSocket) {
    _webSocket.listen(
      (event) {},
      onError: (e, st) {},
      onDone: () {},
    );
  }

  @override
  void addBytes(Uint8List b) {
    _webSocket.add(b);
  }

  @override
  void addString(String s) {
    _webSocket.add(s);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    await _webSocket.close(code, reason);
  }

  @override
  Stream<WebSocketEvent> get events => _events.stream;
}

class CupertinoWebSocket implements WebSocket {
  static Future<CupertinoWebSocket> connect(Uri uri) async {
    late CupertinoWebSocket webSocket;
    final session = URLSession.sessionWithConfiguration(
      URLSessionConfiguration.defaultSessionConfiguration(),
      onWebSocketTaskClosed: (session, task, closeCode, reason) =>
          webSocket._closed(closeCode, reason),
    );
    final task = session.webSocketTaskWithRequest(URLRequest.fromUrl(uri))
      ..resume();
    webSocket = CupertinoWebSocket._(task);
    return webSocket;
  }

  final URLSessionWebSocketTask _task;
  final _events = StreamController<WebSocketEvent>();
  CupertinoWebSocket._(this._task) {
    _task.receiveMessage();
  }

  void _closed(int? closeCode, Data? reason) {
    _events.add(Closed(closeCode)); // XXX
  }

  @override
  void addBytes(Uint8List b) {
    _task
        .sendMessage(URLSessionWebSocketMessage.fromData(Data.fromList(b)))
        .then((_) => _, onError: (e, st) => _events.addError(e, st));
  }

  @override
  void addString(String s) {
    _task
        .sendMessage(URLSessionWebSocketMessage.fromString(s))
        .then((_) => _, onError: (e, st) => _events.addError(e, st));
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    // XXX Wait until all pending writes are done.
    if (code != null) {
      reason = reason ?? "";
      _task.cancelWithCloseCode(code, Data.fromList(reason.codeUnits));
    } else {
      _task.cancel();
    }
  }

  @override
  Stream<WebSocketEvent> get events => _events.stream;
}
