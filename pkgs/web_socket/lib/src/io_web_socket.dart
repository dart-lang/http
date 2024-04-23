// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'utils.dart';
import 'web_socket.dart';

/// A `dart-io`-based [WebSocket] implementation.
///
/// Usable when targeting native platforms.
class IOWebSocket implements WebSocket {
  final io.WebSocket _webSocket;
  final _events = StreamController<WebSocketEvent>();

  /// Create a new WebSocket connection using dart:io WebSocket.
  ///
  /// The URL supplied in [url] must use the scheme ws or wss.
  ///
  /// If provided, the [protocols] argument indicates that subprotocols that
  /// the peer is able to select. See
  /// [RFC-6455 1.9](https://datatracker.ietf.org/doc/html/rfc6455#section-1.9).
  static Future<IOWebSocket> connect(Uri url,
      {Iterable<String>? protocols}) async {
    if (!url.isScheme('ws') && !url.isScheme('wss')) {
      throw ArgumentError.value(
          url, 'url', 'only ws: and wss: schemes are supported');
    }

    final io.WebSocket webSocket;
    try {
      webSocket =
          await io.WebSocket.connect(url.toString(), protocols: protocols);
    } on io.WebSocketException catch (e) {
      throw WebSocketException(e.message);
    }

    if (webSocket.protocol != null &&
        !(protocols ?? []).contains(webSocket.protocol)) {
      // dart:io WebSocket does not correctly validate the returned protocol.
      // See https://github.com/dart-lang/sdk/issues/55106
      await webSocket.close(1002); // protocol error
      throw WebSocketException(
          'unexpected protocol selected by peer: ${webSocket.protocol}');
    }
    return IOWebSocket._(webSocket);
  }

  // Create an `IOWebSocket` from an existing `dart:io` `WebSocket`.
  factory IOWebSocket.fromWebSocket(io.WebSocket webSocket) =>
      IOWebSocket._(webSocket);

  IOWebSocket._(this._webSocket) {
    _webSocket.listen(
      (event) {
        if (_events.isClosed) return;
        switch (event) {
          case String e:
            _events.add(TextDataReceived(e));
          case List<int> e:
            _events.add(BinaryDataReceived(Uint8List.fromList(e)));
        }
      },
      onError: (Object e, StackTrace st) {
        if (_events.isClosed) return;
        final wse = switch (e) {
          io.WebSocketException(message: final message) =>
            WebSocketException(message),
          _ => WebSocketException(e.toString()),
        };
        _events.addError(wse, st);
      },
      onDone: () {
        if (_events.isClosed) return;
        _events
          ..add(
              CloseReceived(_webSocket.closeCode, _webSocket.closeReason ?? ''))
          ..close();
      },
    );
  }

  @override
  void sendBytes(Uint8List b) {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
    }
    _webSocket.add(b);
  }

  @override
  void sendText(String s) {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
    }
    _webSocket.add(s);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
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

  @override
  String get protocol => _webSocket.protocol ?? '';
}

const connect = IOWebSocket.connect;
