// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http_parser.web_socket;

import 'dart:async';

import 'package:crypto/crypto.dart';

import 'copy/web_socket_impl.dart';

/// An implementation of the WebSocket protocol that's not specific to "dart:io"
/// or to any particular HTTP API.
///
/// Because this is HTTP-API-agnostic, it doesn't handle the initial [WebSocket
/// handshake][]. This needs to be handled manually by the user of the code.
/// Once that's been done, [new CompatibleWebSocket] can be called with the
/// underlying socket and it will handle the remainder of the protocol.
///
/// [WebSocket handshake]: https://tools.ietf.org/html/rfc6455#section-4
abstract class CompatibleWebSocket implements Stream, StreamSink {
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
  Duration pingInterval;

  /// The [close code][] set when the WebSocket connection is closed.
  ///
  /// [close code]: https://tools.ietf.org/html/rfc6455#section-7.1.5
  ///
  /// Before the connection has been closed, this will be `null`.
  int get closeCode;

  /// The [close reason][] set when the WebSocket connection is closed.
  ///
  /// [close reason]: https://tools.ietf.org/html/rfc6455#section-7.1.6
  ///
  /// Before the connection has been closed, this will be `null`.
  String get closeReason;

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
  factory CompatibleWebSocket(Stream<List<int>> stream,
        {StreamSink<List<int>> sink, String protocol, bool serverSide: true}) {
    if (sink == null) {
      if (stream is! StreamSink) {
        throw new ArgumentError("If stream isn't also a StreamSink, sink must "
            "be passed explicitly.");
      }
      sink = stream as StreamSink;
    }

    return new WebSocketImpl.fromSocket(stream, sink, protocol, serverSide);
  }

  /// Closes the web socket connection.
  ///
  /// [closeCode] and [closeReason] are the [close code][] and [reason][] sent
  /// to the remote peer, respectively. If they are omitted, the peer will see
  /// a "no status received" code with no reason.
  ///
  /// [close code]: https://tools.ietf.org/html/rfc6455#section-7.1.5
  /// [reason]: https://tools.ietf.org/html/rfc6455#section-7.1.6
  Future close([int closeCode, String closeReason]);
}

/// An exception thrown by [CompatibleWebSocket].
class CompatibleWebSocketException implements Exception {
  final String message;

  CompatibleWebSocketException([this.message]);

  String toString() => message == null
      ? "CompatibleWebSocketException" :
        "CompatibleWebSocketException: $message";
}
