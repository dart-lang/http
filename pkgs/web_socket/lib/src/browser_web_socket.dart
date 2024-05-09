// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../web_socket.dart';
import 'utils.dart';

/// A [WebSocket] using the browser WebSocket API.
///
/// Usable when targeting the browser using either JavaScript or WASM.
class BrowserWebSocket implements WebSocket {
  final web.WebSocket _webSocket;
  final _events = StreamController<WebSocketEvent>();

  /// Create a new WebSocket connection using the JavaScript WebSocket API.
  ///
  /// The URL supplied in [url] must use the scheme ws or wss.
  ///
  /// If provided, the [protocols] argument indicates that subprotocols that
  /// the peer is able to select. See
  /// [RFC-6455 1.9](https://datatracker.ietf.org/doc/html/rfc6455#section-1.9).
  static Future<BrowserWebSocket> connect(Uri url,
      {Iterable<String>? protocols}) async {
    if (!url.isScheme('ws') && !url.isScheme('wss')) {
      throw ArgumentError.value(
          url, 'url', 'only ws: and wss: schemes are supported');
    }

    final webSocket = web.WebSocket(url.toString(),
        protocols?.map((e) => e.toJS).toList().toJS ?? JSArray())
      ..binaryType = 'arraybuffer';
    final browserSocket = BrowserWebSocket._(webSocket);
    final webSocketConnected = Completer<BrowserWebSocket>();

    if (webSocket.readyState == web.WebSocket.OPEN) {
      webSocketConnected.complete(browserSocket);
    } else {
      if (webSocket.readyState == web.WebSocket.CLOSING ||
          webSocket.readyState == web.WebSocket.CLOSED) {
        webSocketConnected.completeError(WebSocketException(
            'Unexpected WebSocket state: ${webSocket.readyState}, '
            'expected CONNECTING (0) or OPEN (1)'));
      } else {
        // The socket API guarantees that only a single open event will be
        // emitted.
        unawaited(webSocket.onOpen.first.then((_) {
          webSocketConnected.complete(browserSocket);
        }));
      }
    }

    unawaited(webSocket.onError.first.then((e) {
      // Unfortunately, the underlying WebSocket API doesn't expose any
      // specific information about the error itself.
      if (!webSocketConnected.isCompleted) {
        final error = WebSocketException('Failed to connect WebSocket');
        webSocketConnected.completeError(error);
      } else {
        browserSocket._closed(1006, 'error');
      }
    }));

    webSocket.onMessage.listen((e) {
      if (browserSocket._events.isClosed) return;

      final eventData = e.data!;
      late WebSocketEvent data;
      if (eventData.typeofEquals('string')) {
        data = TextDataReceived((eventData as JSString).toDart);
      } else if (eventData.typeofEquals('object') &&
          (eventData as JSObject).instanceOfString('ArrayBuffer')) {
        data = BinaryDataReceived(
            (eventData as JSArrayBuffer).toDart.asUint8List());
      } else {
        throw StateError('unexpected message type: ${eventData.runtimeType}');
      }
      browserSocket._events.add(data);
    });

    unawaited(webSocket.onClose.first.then((event) {
      if (!webSocketConnected.isCompleted) {
        webSocketConnected.complete(browserSocket);
      }
      browserSocket._closed(event.code, event.reason);
    }));

    return webSocketConnected.future;
  }

  void _closed(int? code, String? reason) {
    if (_events.isClosed) return;
    _events.add(CloseReceived(code, reason ?? ''));
    unawaited(_events.close());
  }

  BrowserWebSocket._(this._webSocket);

  @override
  void sendBytes(Uint8List b) {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
    }
    // Silently discards the data if the connection is closed.
    _webSocket.send(b.jsify()!);
  }

  @override
  void sendText(String s) {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
    }
    // Silently discards the data if the connection is closed.
    _webSocket.send(s.jsify()!);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
    }

    checkCloseCode(code);
    checkCloseReason(reason);

    unawaited(_events.close());
    if ((code, reason) case (final closeCode?, final closeReason?)) {
      _webSocket.close(closeCode, closeReason);
    } else if (code case final closeCode?) {
      _webSocket.close(closeCode);
    } else {
      _webSocket.close();
    }
  }

  @override
  Stream<WebSocketEvent> get events => _events.stream;

  @override
  String get protocol => _webSocket.protocol;
}

const connect = BrowserWebSocket.connect;
