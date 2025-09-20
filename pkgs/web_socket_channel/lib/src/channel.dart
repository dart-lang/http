// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' as convert;

import 'package:async/async.dart';
import 'package:crypto/crypto.dart';
import 'package:stream_channel/stream_channel.dart';

import '../adapter_web_socket_channel.dart';
import 'exception.dart';

const String _webSocketGUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

/// A [StreamChannel] that communicates over a WebSocket.
///
/// This is implemented by classes that use `dart:io` and `dart:html`.
///
/// All implementations emit [WebSocketChannelException]s. These exceptions wrap
/// the native exception types where possible.
abstract interface class WebSocketChannel extends StreamChannelMixin {
  /// The subprotocol selected by the server.
  ///
  /// For a client socket, this is initially `null`. After the WebSocket
  /// connection is established the value is set to the subprotocol selected by
  /// the server. If no subprotocol is negotiated the value will remain `null`.
  String? get protocol;

  /// The [close code][] set when the WebSocket connection is closed.
  ///
  /// [close code]: https://tools.ietf.org/html/rfc6455#section-7.1.5
  ///
  /// Before the connection has been closed, this will be `null`.
  int? get closeCode;

  /// The [close reason][] set when the WebSocket connection is closed.
  ///
  /// [close reason]: https://tools.ietf.org/html/rfc6455#section-7.1.6
  ///
  /// Before the connection has been closed, this will be `null`.
  String? get closeReason;

  /// A future that will complete when the WebSocket connection has been
  /// established.
  ///
  /// This future must be complete before before data can be sent using
  /// [WebSocketChannel.sink].
  ///
  /// If a connection could not be established (e.g. because of a network
  /// issue), then this future will complete with an error.
  ///
  /// For example:
  /// ```
  /// final channel = WebSocketChannel.connect(Uri.parse('ws://example.com'));
  ///
  /// try {
  ///   await channel.ready;
  /// } on SocketException catch (e) {
  ///   // Handle the exception.
  /// } on WebSocketChannelException catch (e) {
  ///   // Handle the exception.
  /// }
  ///
  /// // If `ready` completes without an error then the channel is ready to
  /// // send data.
  /// channel.sink.add('Hello World');
  /// ```
  Future<void> get ready;

  /// The sink for sending values to the other endpoint.
  ///
  /// This supports additional arguments to [WebSocketSink.close] that provide
  /// the remote endpoint reasons for closing the connection.
  @override
  WebSocketSink get sink;

  /// Signs a `Sec-WebSocket-Key` header sent by a WebSocket client as part of
  /// the [initial handshake][].
  ///
  /// The return value should be sent back to the client in a
  /// `Sec-WebSocket-Accept` header.
  ///
  /// [initial handshake]: https://tools.ietf.org/html/rfc6455#section-4.2.2
  static String signKey(String key)
      // We use [codeUnits] here rather than UTF-8-decoding the string because
      // [key] is expected to be base64 encoded, and so will be pure ASCII.
      =>
      convert.base64
          .encode(sha1.convert((key + _webSocketGUID).codeUnits).bytes);

  /// Creates a new WebSocket connection.
  ///
  /// Connects to [uri] using and returns a channel that can be used to
  /// communicate over the resulting socket.
  ///
  /// The optional [protocols] parameter is the same as `WebSocket.connect`.
  ///
  /// A WebSocketChannel is returned synchronously, however the connection is
  /// not established synchronously.
  /// The [ready] future will complete after the channel is connected.
  /// If there are errors creating the connection the [ready] future will
  /// complete with an error.
  static WebSocketChannel connect(Uri uri, {Iterable<String>? protocols}) =>
      AdapterWebSocketChannel.connect(uri, protocols: protocols);
}

/// The sink exposed by a [WebSocketChannel].
///
/// This is like a normal [StreamSink], except that it supports extra arguments
/// to [close].
abstract interface class WebSocketSink implements DelegatingStreamSink {
  /// Closes the web socket connection.
  ///
  /// [closeCode] and [closeReason] are the [close code][] and [reason][] sent
  /// to the remote peer, respectively. If they are omitted, the peer will see
  /// a "no status received" code with no reason.
  ///
  /// [close code]: https://tools.ietf.org/html/rfc6455#section-7.1.5
  /// [reason]: https://tools.ietf.org/html/rfc6455#section-7.1.6
  @override
  Future close([int? closeCode, String? closeReason]);
}
