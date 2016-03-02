// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';

import 'src/channel.dart';
import 'src/exception.dart';
import 'src/sink_completer.dart';

/// A [WebSocketChannel] that communicates using a `dart:io` [WebSocket].
class IOWebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  /// The underlying `dart:io` [WebSocket].
  ///
  /// If the channel was constructed with [IOWebSocketChannel.connect], this is
  /// `null` until the [WebSocket.connect] future completes.
  WebSocket _webSocket;

  Duration get pingInterval =>
      _webSocket == null ? _pingInterval : _webSocket.pingInterval;

  set pingInterval(Duration value) {
    if (_webSocket == null) {
      _pingInterval = value;
    } else {
      _webSocket.pingInterval = value;
    }
  }

  /// The ping interval set by the user.
  ///
  /// This is stored independently of [_webSocket] so that the user can set it
  /// prior to [_webSocket] getting a value.
  Duration _pingInterval;

  String get protocol => _webSocket?.protocol;
  int get closeCode => _webSocket?.closeCode;
  String get closeReason => _webSocket?.closeReason;

  final Stream stream;
  final WebSocketSink sink;

  // TODO(nweiz): Add a compression parameter after the initial release.

  /// Creates a new WebSocket connection.
  ///
  /// Connects to [url] using [WebSocket.connect] and returns a channel that can
  /// be used to communicate over the resulting socket. The [url] may be either
  /// a [String] or a [Uri]; otherwise, the parameters are the same as
  /// [WebSocket.connect].
  ///
  /// If there's an error connecting, the channel's stream emits a
  /// [WebSocketChannelException] wrapping that error and then closes.
  factory IOWebSocketChannel.connect(url, {Iterable<String> protocols,
      Map<String, dynamic> headers}) {
    var channel;
    var sinkCompleter = new WebSocketSinkCompleter();
    var stream = StreamCompleter.fromFuture(
        WebSocket.connect(url.toString(), headers: headers).then((webSocket) {
      channel._setWebSocket(webSocket);
      sinkCompleter.setDestinationSink(new _IOWebSocketSink(webSocket));
      return webSocket;
    }).catchError((error) => throw new WebSocketChannelException.from(error)));

    channel = new IOWebSocketChannel._withoutSocket(stream, sinkCompleter.sink);
    return channel;
  }

  /// Creates a channel wrapping [socket].
  IOWebSocketChannel(WebSocket socket)
      : _webSocket = socket,
        stream = socket.handleError((error) =>
            throw new WebSocketChannelException.from(error)),
        sink = new _IOWebSocketSink(socket);

  /// Creates a channel without a socket.
  ///
  /// This is used with [connect] to synchronously provide a channel that later
  /// has a socket added.
  IOWebSocketChannel._withoutSocket(Stream stream, this.sink)
      : _webSocket = null,
        stream = stream.handleError((error) =>
            throw new WebSocketChannelException.from(error));

  /// Sets the underlying web socket.
  ///
  /// This is called by [connect] once the [WebSocket.connect] future has
  /// completed.
  void _setWebSocket(WebSocket webSocket) {
    assert(_webSocket == null);

    _webSocket = webSocket;
    if (_pingInterval != null) _webSocket.pingInterval = pingInterval;
  }
}

/// A [WebSocketSink] that forwards [close] calls to a `dart:io` [WebSocket].
class _IOWebSocketSink extends DelegatingStreamSink implements WebSocketSink {
  /// The underlying socket.
  final WebSocket _webSocket;

  _IOWebSocketSink(WebSocket webSocket)
      : super(webSocket),
        _webSocket = webSocket;

  Future close([int closeCode, String closeReason]) =>
      _webSocket.close(closeCode, closeReason);
}
