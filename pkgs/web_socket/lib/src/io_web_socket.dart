// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import '../web_socket.dart';
import 'utils.dart';

/// A `dart-io`-based [WebSocket] implementation.
///
/// Usable when targeting native platforms.
class IOWebSocket implements WebSocket {
  final io.WebSocket _webSocket;
  final _events = StreamController<WebSocketEvent>();

  static Future<IOWebSocket> connect(Uri url,
      {Iterable<String>? protocols}) async {
    try {
      final webSocket = await io.WebSocket.connect(url.toString());
      return IOWebSocket._(webSocket);
    } on io.WebSocketException catch (e) {
      throw WebSocketException(e.message);
    }
  }

  IOWebSocket._(this._webSocket) {
    _webSocket.listen(
      (event) {
        switch (event) {
          case String e:
            _events.add(TextDataReceived(e));
          case List<int> e:
            _events.add(BinaryDataReceived(Uint8List.fromList(e)));
        }
      },
      onError: (Object e, StackTrace st) {
        final wse = switch (e) {
          io.WebSocketException(message: final message) =>
            WebSocketException(message),
          _ => WebSocketException(e.toString()),
        };
        _events.addError(wse, st);
      },
      onDone: () {
        if (!_events.isClosed) {
          _events
            ..add(CloseReceived(
                _webSocket.closeCode, _webSocket.closeReason ?? ''))
            ..close();
        }
      },
    );
  }

  @override
  void sendBytes(Uint8List b) {
    if (_events.isClosed) {
      throw StateError('WebSocket is closed');
    }
    _webSocket.add(b);
  }

  @override
  void sendText(String s) {
    if (_events.isClosed) {
      throw StateError('WebSocket is closed');
    }
    _webSocket.add(s);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_events.isClosed) {
      throw StateError('WebSocket is closed');
    }

    checkCloseCode(code);
    checkCloseReason(reason);

    unawaited(_events.close());
    try {
      await _webSocket.close(code, reason);
    } on io.WebSocketException catch (e) {
      throw WebSocketException(e.message);
    }
  }

  @override
  Stream<WebSocketEvent> get events => _events.stream;
}

const connect = IOWebSocket.connect;
