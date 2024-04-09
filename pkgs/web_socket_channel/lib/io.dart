// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io' show HttpClient, WebSocket;

import 'package:web_socket/io_web_socket.dart' show IOWebSocket;

import 'adapter_web_socket_channel.dart';
import 'src/channel.dart';
import 'src/exception.dart';

/// A [WebSocketChannel] that communicates using a `dart:io` [WebSocket].
class IOWebSocketChannel extends AdapterWebSocketChannel {
  /// Creates a new WebSocket connection.
  ///
  /// Connects to [url] using [WebSocket.connect] and returns a channel that can
  /// be used to communicate over the resulting socket. The [url] may be either
  /// a [String] or a [Uri]. The [protocols] and [headers] parameters are the
  /// same as [WebSocket.connect].
  ///
  /// [pingInterval] controls the interval for sending ping signals. If a ping
  /// message is not answered by a pong message from the peer, the WebSocket is
  /// assumed disconnected and the connection is closed with a `goingAway` code.
  /// When a ping signal is sent, the pong message must be received within
  /// [pingInterval]. It defaults to `null`, indicating that ping messages are
  /// disabled.
  ///
  /// [connectTimeout] determines how long to wait for [WebSocket.connect]
  /// before throwing a [TimeoutException]. If connectTimeout is null then the
  /// connection process will never time-out.
  ///
  /// If there's an error connecting, the channel's stream emits a
  /// [WebSocketChannelException] wrapping that error and then closes.
  factory IOWebSocketChannel.connect(
    Object url, {
    Iterable<String>? protocols,
    Map<String, dynamic>? headers,
    Duration? pingInterval,
    Duration? connectTimeout,
    HttpClient? customClient,
  }) {
    var webSocketFuture = WebSocket.connect(
      url.toString(),
      headers: headers,
      protocols: protocols,
      customClient: customClient,
    ).then((webSocket) => webSocket..pingInterval = pingInterval);

    if (connectTimeout != null) {
      webSocketFuture = webSocketFuture.timeout(connectTimeout);
    }

    return IOWebSocketChannel(webSocketFuture);
  }

  /// Creates a channel wrapping [webSocket].
  IOWebSocketChannel(FutureOr<WebSocket> webSocket)
      : super(webSocket is Future<WebSocket>
            ? webSocket.then(IOWebSocket.fromWebSocket) as FutureOr<IOWebSocket>
            : IOWebSocket.fromWebSocket(webSocket));
}
