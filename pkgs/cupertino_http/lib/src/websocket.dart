import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:websocket/websocket.dart';

class CupertinoWebSocketException extends XXXWebSocketException {
  CupertinoWebSocketException([super.message = '']);

  factory CupertinoWebSocketException.fromError(Error e) =>
      CupertinoWebSocketException(e.toString());
}

class CupertinoWebSocket implements WebSocket {
  static Future<CupertinoWebSocket> connect(Uri uri) async {
    final readyCompleter = Completer<void>();
    late CupertinoWebSocket webSocket;

    final session = URLSession.sessionWithConfiguration(
        URLSessionConfiguration.defaultSessionConfiguration(),
        onComplete: (session, task, error) {
      print('onComplete:');
      if (!readyCompleter.isCompleted) {
        if (error != null) {
          readyCompleter
              .completeError(CupertinoWebSocketException.fromError(error));
        } else {
          readyCompleter.complete();
        }
      } else {
        webSocket._closed(1006, Data.fromList('abnormal close'.codeUnits));
      }
    }, onWebSocketTaskOpened: (session, task, protocol) {
      print('onWebSocketTaskOpened:');
//        _protocol = protocol;
      readyCompleter.complete();
    }, onWebSocketTaskClosed: (session, task, closeCode, reason) {
      print('onWebSocketTaskClosed: $closeCode');
      webSocket._closed(closeCode, reason);
    });
    print(uri);
    final task = session.webSocketTaskWithRequest(URLRequest.fromUrl(uri))
      ..resume();
    await readyCompleter.future;
    return webSocket = CupertinoWebSocket._(task);
  }

  final URLSessionWebSocketTask _task;
  final _events = StreamController<WebSocketEvent>();

  void handleMessage(URLSessionWebSocketMessage value) {
    print('handleMessage: $value');
    late WebSocketEvent v;
    switch (value.type) {
      case URLSessionWebSocketMessageType.urlSessionWebSocketMessageTypeString:
        v = TextDataReceived(value.string!);
        break;
      case URLSessionWebSocketMessageType.urlSessionWebSocketMessageTypeData:
        v = BinaryDataReceived(value.data!.bytes);
        break;
    }
    _events.add(v);
    scheduleReceive();
  }

  void scheduleReceive() {
//    print('scheduleReceive');
    _task.receiveMessage().then(handleMessage, onError: _closeWithError);
  }

  CupertinoWebSocket._(this._task) {
    scheduleReceive();
  }

  void _closeWithError(Object e) {
    print('closedWithError: $e');
    if (e is Error) {
      if (e.domain == 'NSPOSIXErrorDomain' && e.code == 57) {
        // Socket is not connected.
        // onWebSocketTaskClosed/onComplete will be invoked and may indicate a
        // close code.
        return;
      }
      var (int code, String? reason) = switch ([e.domain, e.code]) {
        ['NSPOSIXErrorDomain', 100] => (1002, e.localizedDescription),
        _ => (1006, e.localizedDescription)
      };
      _task.cancel();
      _closed(code, reason == null ? null : Data.fromList(reason.codeUnits));
    } else {
      throw UnsupportedError('');
    }
  }

  void _closed(int? closeCode, Data? reason) {
    print('closing with $closeCode');
    if (!_events.isClosed) {
      final closeReason = reason == null ? null : utf8.decode(reason.bytes);

      _events
        ..add(Closed(closeCode, closeReason))
        ..close();
    }
  }

  @override
  void addBytes(Uint8List b) {
    if (_events.isClosed) {
      throw StateError('WebSocket is closed');
    }
    _task
        .sendMessage(URLSessionWebSocketMessage.fromData(Data.fromList(b)))
        .then((_) => _, onError: _closeWithError);
  }

  @override
  void addString(String s) {
    if (_events.isClosed) {
      throw StateError('WebSocket is closed');
    }
    _task
        .sendMessage(URLSessionWebSocketMessage.fromString(s))
        .then((_) => _, onError: _closeWithError);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!_events.isClosed) {
      unawaited(_events.close());

      // XXX Wait until all pending writes are done.
      print('close($code, $reason)');
      if (code != null) {
        reason = reason ?? '';
        _task.cancelWithCloseCode(code, Data.fromList(reason.codeUnits));
      } else {
        _task.cancel();
      }
    }
  }

  @override
  Stream<WebSocketEvent> get events => _events.stream;
}

/*
    test('with code and reason', () async {
      final channel = await channelFactory(uri);

      channel.addString('Please close');
      expect(await channel.events.toList(),
          [Closed(4123, 'server closed the connection')]);
    });
*/
