// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket/web_socket.dart';

import 'src/channel.dart';
import 'src/exception.dart';

/// A [WebSocketChannel] implemented using [WebSocket].
class WebSocketAdapterWebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  @override
  String? get protocol => _protocol;
  String? _protocol;

  @override
  int? get closeCode => _closeCode;
  int? _closeCode;

  @override
  String? get closeReason => _closeReason;
  String? _closeReason;

  /// The close code set by the local user.
  ///
  /// To ensure proper ordering, this is stored until we get a done event on
  /// [_controller.local.stream].
  int? _localCloseCode;

  /// The close reason set by the local user.
  ///
  /// To ensure proper ordering, this is stored until we get a done event on
  /// [_controller.local.stream].
  String? _localCloseReason;

  /// Completer for [ready].
  final _readyCompleter = Completer<void>();

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  Stream get stream => _controller.foreign.stream;

  final _controller =
      StreamChannelController<Object?>(sync: true, allowForeignErrors: false);

  @override
  late final WebSocketSink sink = _WebSocketSink(this);

  /// Creates a new WebSocket connection.
  ///
  /// If provided, the [protocols] argument indicates that subprotocols that
  /// the peer is able to select. See
  /// [RFC-6455 1.9](https://datatracker.ietf.org/doc/html/rfc6455#section-1.9).
  ///
  /// After construction, the [WebSocketAdapterWebSocketChannel] may not be
  /// connected to the peer. The [ready] future will complete after the channel
  /// is connected. If there are errors creating the connection the [ready]
  /// future will complete with an error.
  factory WebSocketAdapterWebSocketChannel.connect(Uri url,
          {Iterable<String>? protocols}) =>
      WebSocketAdapterWebSocketChannel._(
          WebSocket.connect(url, protocols: protocols));

  // Create a [WebSocketWebSocketChannelAdapter] from an existing [WebSocket].
  factory WebSocketAdapterWebSocketChannel.fromWebSocket(WebSocket webSocket) =>
      WebSocketAdapterWebSocketChannel._(Future.value(webSocket));

  WebSocketAdapterWebSocketChannel._(Future<WebSocket> webSocketFuture) {
    webSocketFuture.then((webSocket) {
      var remoteClosed = false;
      webSocket.events.listen((event) {
        switch (event) {
          case TextDataReceived(text: final text):
            _controller.local.sink.add(text);
          case BinaryDataReceived(data: final data):
            _controller.local.sink.add(data);
          case CloseReceived(code: final code, reason: final reason):
            remoteClosed = true;
            _closeCode = code;
            _closeReason = reason;
            _controller.local.sink.close();
        }
      });
      _controller.local.stream.listen((obj) {
        try {
          switch (obj) {
            case final String s:
              webSocket.sendText(s);
            case final Uint8List b:
              webSocket.sendBytes(b);
            case final List<int> b:
              webSocket.sendBytes(Uint8List.fromList(b));
            default:
              throw UnsupportedError('Cannot send ${obj.runtimeType}');
          }
        } on WebSocketConnectionClosed catch (_) {
          // There is nowhere to surface this error; `_controller.local.sink`
          // has already been closed.
        }
      }, onDone: () {
        if (!remoteClosed) {
          webSocket.close(_localCloseCode, _localCloseReason);
        }
      });
      _protocol = webSocket.protocol;
      _readyCompleter.complete();
    }, onError: (Object e) {
      _readyCompleter.completeError(WebSocketChannelException.from(e));
    });
  }
}

/// A [WebSocketSink] that tracks the close code and reason passed to [close].
class _WebSocketSink extends DelegatingStreamSink implements WebSocketSink {
  /// The channel to which this sink belongs.
  final WebSocketAdapterWebSocketChannel _channel;

  _WebSocketSink(WebSocketAdapterWebSocketChannel channel)
      : _channel = channel,
        super(channel._controller.foreign.sink);

  @override
  Future close([int? closeCode, String? closeReason]) {
    _channel._localCloseCode = closeCode;
    _channel._localCloseReason = closeReason;
    return super.close();
  }
}
