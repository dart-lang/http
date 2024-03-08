import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket/web_socket.dart';

import 'cupertino_api.dart';

/// An error occurred while connecting to the peer.
class ConnectionErrorException extends WebSocketException {
  final Error error;

  ConnectionErrorException(super.message, this.error);

  @override
  String toString() => 'CupertinoErrorWebSocketException: $message $error';
}

/// A [WebSocket] using the
/// [NSURLSessionWebSocketTask API](https://developer.apple.com/documentation/foundation/nsurlsessionwebsockettask).
class CupertinoWebSocket implements WebSocket {
  /// Create a new WebSocket connection using the
  /// [NSURLSessionWebSocketTask API](https://developer.apple.com/documentation/foundation/nsurlsessionwebsockettask).
  ///
  /// The URL supplied in [url] must use the scheme ws or wss.
  ///
  /// If provided, the [protocols] argument indicates that subprotocols that
  /// the peer is able to select. See
  /// [RFC-6455 1.9](https://datatracker.ietf.org/doc/html/rfc6455#section-1.9).
  static Future<CupertinoWebSocket> connect(Uri url,
      {Iterable<String>? protocols}) async {
    if (!url.isScheme('ws') && !url.isScheme('wss')) {
      throw ArgumentError.value(
          url, 'url', 'only ws: and wss: schemes are supported');
    }

    final readyCompleter = Completer<CupertinoWebSocket>();
    late CupertinoWebSocket webSocket;

    final session = URLSession.sessionWithConfiguration(
        URLSessionConfiguration.defaultSessionConfiguration(),
        onComplete: (session, task, error) {
      if (!readyCompleter.isCompleted) {
        if (error != null) {
          readyCompleter.completeError(
              ConnectionErrorException('connection ended unexpectedly', error));
        } else {
          webSocket = CupertinoWebSocket._(task as URLSessionWebSocketTask, '');
          readyCompleter.complete(webSocket);
        }
      } else {
        webSocket._connectionClosed(
            1006, Data.fromList('abnormal close'.codeUnits));
      }
    }, onWebSocketTaskOpened: (session, task, protocol) {
      webSocket = CupertinoWebSocket._(task, protocol ?? '');
      readyCompleter.complete(webSocket);
    }, onWebSocketTaskClosed: (session, task, closeCode, reason) {
      webSocket._connectionClosed(closeCode, reason);
    });

    session.webSocketTaskWithURL(url, protocols: protocols).resume();
    return readyCompleter.future;
  }

  final URLSessionWebSocketTask _task;
  final String _protocol;
  final _events = StreamController<WebSocketEvent>();

  CupertinoWebSocket._(this._task, this._protocol) {
    _scheduleReceive();
  }

  /// Handle an incoming message from the peer and schedule receiving the next
  /// message.
  void _handleMessage(URLSessionWebSocketMessage value) {
    late WebSocketEvent event;
    switch (value.type) {
      case URLSessionWebSocketMessageType.urlSessionWebSocketMessageTypeString:
        event = TextDataReceived(value.string!);
        break;
      case URLSessionWebSocketMessageType.urlSessionWebSocketMessageTypeData:
        event = BinaryDataReceived(value.data!.bytes);
        break;
    }
    _events.add(event);
    _scheduleReceive();
  }

  void _scheduleReceive() {
    unawaited(_task
        .receiveMessage()
        .then(_handleMessage, onError: _closeConnectionWithError));
  }

  /// Close the WebSocket connection due to an error and send the
  /// [CloseReceived] event.
  void _closeConnectionWithError(Object e) {
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
      _connectionClosed(
          code, reason == null ? null : Data.fromList(reason.codeUnits));
    } else {
      throw StateError('unexpected error: $e');
    }
  }

  void _connectionClosed(int? closeCode, Data? reason) {
    if (!_events.isClosed) {
      final closeReason = reason == null ? '' : utf8.decode(reason.bytes);

      _events
        ..add(CloseReceived(closeCode, closeReason))
        ..close();
    }
  }

  @override
  void sendBytes(Uint8List b) {
    if (_events.isClosed) {
      throw StateError('WebSocket is closed');
    }
    _task
        .sendMessage(URLSessionWebSocketMessage.fromData(Data.fromList(b)))
        .then((_) => _, onError: _closeConnectionWithError);
  }

  @override
  void sendText(String s) {
    if (_events.isClosed) {
      throw StateError('WebSocket is closed');
    }
    _task
        .sendMessage(URLSessionWebSocketMessage.fromString(s))
        .then((_) => _, onError: _closeConnectionWithError);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_events.isClosed) {
      throw StateError('WebSocket is closed');
    }

    if (code != null) {
      RangeError.checkValueInInterval(code, 3000, 4999, 'code');
    }
    if (reason != null && utf8.encode(reason).length > 123) {
      throw ArgumentError.value(reason, 'reason',
          'reason must be <= 123 bytes long when encoded as UTF-8');
    }

    if (!_events.isClosed) {
      unawaited(_events.close());
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

  @override
  String get protocol => _protocol;
}
