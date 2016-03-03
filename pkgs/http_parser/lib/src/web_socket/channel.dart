// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:crypto/crypto.dart';
import 'package:stream_channel/stream_channel.dart';

import '../copy/web_socket_impl.dart';

/// This class is deprecated.
///
/// Use the [`web_socket_channel`][web_socket_channel] package instead.
///
/// [web_socket_channel]: https://pub.dartlang.org/packages/web_socket_channel
@Deprecated("Will be removed in 3.0.0.")
class WebSocketChannel extends StreamChannelMixin {
  /// The underlying web socket.
  ///
  /// This is essentially a copy of `dart:io`'s WebSocket implementation, with
  /// the IO-specific pieces factored out.
  final WebSocketImpl _webSocket;

  /// The interval for sending ping signals.
  ///
  /// If a ping message is not answered by a pong message from the peer, the
  /// `WebSocket` is assumed disconnected and the connection is closed with a
  /// [WebSocketStatus.GOING_AWAY] close code. When a ping signal is sent, the
  /// pong message must be received within [pingInterval].
  ///
  /// There are never two outstanding pings at any given time, and the next ping
  /// timer starts when the pong is received.
  ///
  /// By default, the [pingInterval] is `null`, indicating that ping messages
  /// are disabled.
  Duration get pingInterval => _webSocket.pingInterval;
  set pingInterval(Duration value) => _webSocket.pingInterval = value;

  /// The [close code][] set when the WebSocket connection is closed.
  ///
  /// [close code]: https://tools.ietf.org/html/rfc6455#section-7.1.5
  ///
  /// Before the connection has been closed, this will be `null`.
  int get closeCode => _webSocket.closeCode;

  /// The [close reason][] set when the WebSocket connection is closed.
  ///
  /// [close reason]: https://tools.ietf.org/html/rfc6455#section-7.1.6
  ///
  /// Before the connection has been closed, this will be `null`.
  String get closeReason => _webSocket.closeReason;

  Stream get stream => new StreamView(_webSocket);

  /// The sink for sending values to the other endpoint.
  ///
  /// This has additional arguments to [WebSocketSink.close] arguments that
  /// provide the remote endpoint reasons for closing the connection.
  WebSocketSink get sink => new WebSocketSink._(_webSocket);

  /// Signs a `Sec-WebSocket-Key` header sent by a WebSocket client as part of
  /// the [initial handshake].
  ///
  /// The return value should be sent back to the client in a
  /// `Sec-WebSocket-Accept` header.
  ///
  /// [initial handshake]: https://tools.ietf.org/html/rfc6455#section-4.2.2
  static String signKey(String key) {
    var hash = new SHA1();
    // We use [codeUnits] here rather than UTF-8-decoding the string because
    // [key] is expected to be base64 encoded, and so will be pure ASCII.
    hash.add((key + webSocketGUID).codeUnits);
    return CryptoUtils.bytesToBase64(hash.close());
  }

  /// Creates a new WebSocket handling messaging across an existing socket.
  ///
  /// Because this is HTTP-API-agnostic, the initial [WebSocket handshake][]
  /// must have already been completed on the socket before this is called.
  ///
  /// If [stream] is also a [StreamSink] (for example, if it's a "dart:io"
  /// `Socket`), it will be used for both sending and receiving data. Otherwise,
  /// it will be used for receiving data and [sink] will be used for sending it.
  ///
  /// [protocol] should be the protocol negotiated by this handshake, if any.
  ///
  /// If this is a WebSocket server, [serverSide] should be `true` (the
  /// default); if it's a client, [serverSide] should be `false`.
  ///
  /// [WebSocket handshake]: https://tools.ietf.org/html/rfc6455#section-4
  WebSocketChannel(StreamChannel<List<int>> channel,
        {String protocol, bool serverSide: true})
      : _webSocket = new WebSocketImpl.fromSocket(
          channel.stream, channel.sink, protocol, serverSide);
}

/// This class is deprecated.
///
/// Use the [`web_socket_channel`][web_socket_channel] package instead.
///
/// [web_socket_channel]: https://pub.dartlang.org/packages/web_socket_channel
@Deprecated("Will be removed in 3.0.0.")
class WebSocketSink extends DelegatingStreamSink {
  final WebSocketImpl _webSocket;

  WebSocketSink._(WebSocketImpl webSocket)
      : super(webSocket),
        _webSocket = webSocket;

  /// Closes the web socket connection.
  ///
  /// [closeCode] and [closeReason] are the [close code][] and [reason][] sent
  /// to the remote peer, respectively. If they are omitted, the peer will see
  /// a "no status received" code with no reason.
  ///
  /// [close code]: https://tools.ietf.org/html/rfc6455#section-7.1.5
  /// [reason]: https://tools.ietf.org/html/rfc6455#section-7.1.6
  Future close([int closeCode, String closeReason]) =>
      _webSocket.close(closeCode, closeReason);
}
