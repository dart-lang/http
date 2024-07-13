// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket/web_socket.dart';

import 'cupertino_api.dart';

/// An error occurred while connecting to the peer.
class ConnectionException extends WebSocketException {
  final Error error;

  ConnectionException(super.message, this.error);

  @override
  String toString() => 'CupertinoErrorWebSocketException: $message $error';
}

/// A [WebSocket] implemented using the
/// [NSURLSessionWebSocketTask API](https://developer.apple.com/documentation/foundation/nsurlsessionwebsockettask).
///
/// NOTE: the [WebSocket] interface is currently experimental and may change in
/// the future.
///
/// ```dart
/// import 'package:cupertino_http/cupertino_http.dart';
/// import 'package:web_socket/web_socket.dart';
///
/// void main() async {
///   final socket = await CupertinoWebSocket.connect(
///       Uri.parse('wss://ws.postman-echo.com/raw'));
///
///   socket.events.listen((e) async {
///     switch (e) {
///       case TextDataReceived(text: final text):
///         print('Received Text: $text');
///         await socket.close();
///       case BinaryDataReceived(data: final data):
///         print('Received Binary: $data');
///       case CloseReceived(code: final code, reason: final reason):
///         print('Connection to server closed: $code [$reason]');
///     }
///   });
/// }
/// ```
class CupertinoWebSocket implements WebSocket {
  /// Create a new WebSocket connection using the
  /// [NSURLSessionWebSocketTask API](https://developer.apple.com/documentation/foundation/nsurlsessionwebsockettask).
  ///
  /// The URL supplied in [url] must use the scheme ws or wss.
  ///
  /// If provided, the [protocols] argument indicates that subprotocols that
  /// the peer is able to select. See
  /// [RFC-6455 1.9](https://datatracker.ietf.org/doc/html/rfc6455#section-1.9).
  ///
  /// NOTE: the [WebSocket] interface is currently experimental and may change
  /// in the future.
  static Future<CupertinoWebSocket> connect(Uri url,
      {Iterable<String>? protocols, URLSessionConfiguration? config}) async {
    if (!url.isScheme('ws') && !url.isScheme('wss')) {
      throw ArgumentError.value(
          url, 'url', 'only ws: and wss: schemes are supported');
    }

    final readyCompleter = Completer<CupertinoWebSocket>();
    late CupertinoWebSocket webSocket;

    final session = URLSession.sessionWithConfiguration(
        config ?? URLSessionConfiguration.defaultSessionConfiguration(),
        // In a successful flow, the callbacks will be made in this order:
        // onWebSocketTaskOpened(...)        // Good connect.
        // <receive/send messages to the peer>
        // onWebSocketTaskClosed(...)        // Optional: peer sent Close frame.
        // onComplete(..., error=null)       // Disconnected.
        //
        // In a failure to connect to the peer, the flow will be:
        // onComplete(session, task, error=error):
        //
        // `onComplete` can also be called at any point if the peer is
        // disconnected without Close frames being exchanged.
        onWebSocketTaskOpened: (session, task, protocol) {
      webSocket = CupertinoWebSocket._(task, protocol ?? '');
      readyCompleter.complete(webSocket);
    }, onWebSocketTaskClosed: (session, task, closeCode, reason) {
      assert(readyCompleter.isCompleted);
      webSocket._connectionClosed(closeCode, reason);
    }, onComplete: (session, task, error) {
      if (!readyCompleter.isCompleted) {
        // `onWebSocketTaskOpened should have been called and completed
        // `readyCompleter`. So either there was a error creating the connection
        // or a logic error.
        if (error == null) {
          throw AssertionError(
              'expected an error or "onWebSocketTaskOpened" to be called '
              'first');
        }
        readyCompleter.completeError(
            ConnectionException('connection ended unexpectedly', error));
      } else {
        // There are three possibilities here:
        // 1. the peer sent a close Frame, `onWebSocketTaskClosed` was already
        //    called and `_connectionClosed` is a no-op.
        // 2. we sent a close Frame (through `close()`) and `_connectionClosed`
        //    is a no-op.
        // 3. an error occurred (e.g. network failure) and `_connectionClosed`
        //    will signal that and close `event`.
        webSocket._connectionClosed(
            1006, Data.fromList('abnormal close'.codeUnits));
      }
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
    if (_events.isClosed) return;

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
      throw WebSocketConnectionClosed();
    }
    _task
        .sendMessage(URLSessionWebSocketMessage.fromData(Data.fromList(b)))
        .then((value) => value, onError: _closeConnectionWithError);
  }

  @override
  void sendText(String s) {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
    }
    _task
        .sendMessage(URLSessionWebSocketMessage.fromString(s))
        .then((value) => value, onError: _closeConnectionWithError);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
    }

    if (code != null && code != 1000 && !(code >= 3000 && code <= 4999)) {
      throw ArgumentError('Invalid argument: $code, close code must be 1000 or '
          'in the range 3000-4999');
    }
    if (reason != null && utf8.encode(reason).length > 123) {
      throw ArgumentError.value(reason, 'reason',
          'reason must be <= 123 bytes long when encoded as UTF-8');
    }

    if (!_events.isClosed) {
      unawaited(_events.close());
      if (code != null) {
        reason = reason ?? '';
        _task.cancelWithCloseCode(code, Data.fromList(utf8.encode(reason)));
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
