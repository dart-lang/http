// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web/web.dart';

import 'src/channel.dart';
import 'src/exception.dart';

/// A [WebSocketChannel] that communicates using a `dart:html` [WebSocket].
class HtmlWebSocketChannel extends StreamChannelMixin
    implements WebSocketChannel {
  /// The underlying `dart:html` [WebSocket].
  final WebSocket innerWebSocket;

  @override
  String? get protocol => innerWebSocket.protocol;

  @override
  int? get closeCode => _closeCode;
  int? _closeCode;

  @override
  String? get closeReason => _closeReason;
  String? _closeReason;

  /// The number of bytes of data that have been queued but not yet transmitted
  /// to the network.
  int? get bufferedAmount => innerWebSocket.bufferedAmount;

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
  late Completer<void> _readyCompleter;

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  Stream get stream => _controller.foreign.stream;

  final _controller =
      StreamChannelController<Object?>(sync: true, allowForeignErrors: false);

  @override
  late final WebSocketSink sink = _HtmlWebSocketSink(this);

  /// Creates a new WebSocket connection.
  ///
  /// Connects to [url] using [WebSocket.new] and returns a channel that can be
  /// used to communicate over the resulting socket. The [url] may be either a
  /// [String] or a [Uri]. The [protocols] parameter is the same as for
  /// [WebSocket.new].
  ///
  /// The [binaryType] parameter controls what type is used for binary messages
  /// received by this socket. It defaults to [BinaryType.list], which causes
  /// binary messages to be delivered as [Uint8List]s. If it's
  /// [BinaryType.blob], they're delivered as [Blob]s instead.
  HtmlWebSocketChannel.connect(Object url,
      {Iterable<String>? protocols, BinaryType? binaryType})
      : this(
          WebSocket(
            url.toString(),
            protocols?.map((e) => e.toJS).toList().toJS ?? JSArray(),
          )..binaryType = (binaryType ?? BinaryType.list).value,
        );

  /// Creates a channel wrapping [webSocket].
  ///
  /// The parameter [webSocket] should be either a dart:html `WebSocket`
  /// instance or a package:web [WebSocket] instance.
  HtmlWebSocketChannel(Object /*WebSocket*/ webSocket)
      : innerWebSocket = webSocket as WebSocket {
    _readyCompleter = Completer();
    if (innerWebSocket.readyState == WebSocket.OPEN) {
      _readyCompleter.complete();
      _listen();
    } else {
      if (innerWebSocket.readyState == WebSocket.CLOSING ||
          innerWebSocket.readyState == WebSocket.CLOSED) {
        _readyCompleter.completeError(WebSocketChannelException(
            'WebSocket state error: ${innerWebSocket.readyState}'));
      }
      // The socket API guarantees that only a single open event will be
      // emitted.
      innerWebSocket.onOpen.first.then((_) {
        _readyCompleter.complete();
        _listen();
      });
    }

    // The socket API guarantees that only a single error event will be emitted,
    // and that once it is no open or message events will be emitted.
    innerWebSocket.onError.first.then((_) {
      // Unfortunately, the underlying WebSocket API doesn't expose any
      // specific information about the error itself.
      final error = WebSocketChannelException('WebSocket connection failed.');
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.completeError(error);
      }
      _controller.local.sink.addError(error);
      _controller.local.sink.close();
    });

    innerWebSocket.onMessage.listen(_innerListen);

    // The socket API guarantees that only a single error event will be emitted,
    // and that once it is no other events will be emitted.
    innerWebSocket.onClose.first.then((event) {
      _closeCode = event.code;
      _closeReason = event.reason;
      _controller.local.sink.close();
    });
  }

  void _innerListen(MessageEvent event) {
    // Event data will be ArrayBuffer, Blob, or String.
    final eventData = event.data;
    final Object? data;
    if (eventData.typeofEquals('string')) {
      data = (eventData as JSString).toDart;
    } else if (eventData.typeofEquals('object') &&
        (eventData as JSObject).instanceOfString('ArrayBuffer')) {
      data = (eventData as JSArrayBuffer).toDart.asUint8List();
    } else {
      // Blobs are passed directly.
      data = eventData;
    }
    _controller.local.sink.add(data);
  }

  /// Pipes user events to [innerWebSocket].
  void _listen() {
    _controller.local.stream.listen((obj) => innerWebSocket.send(obj!.jsify()!),
        onDone: () {
      // On Chrome and possibly other browsers, `null` can't be passed as the
      // default here. The actual arity of the function call must be correct or
      // it will fail.
      if ((_localCloseCode, _localCloseReason)
          case (final closeCode?, final closeReason?)) {
        innerWebSocket.close(closeCode, closeReason);
      } else if (_localCloseCode case final closeCode?) {
        innerWebSocket.close(closeCode);
      } else {
        innerWebSocket.close();
      }
    });
  }
}

/// A [WebSocketSink] that tracks the close code and reason passed to [close].
class _HtmlWebSocketSink extends DelegatingStreamSink implements WebSocketSink {
  /// The channel to which this sink belongs.
  final HtmlWebSocketChannel _channel;

  _HtmlWebSocketSink(HtmlWebSocketChannel channel)
      : _channel = channel,
        super(channel._controller.foreign.sink);

  @override
  Future close([int? closeCode, String? closeReason]) {
    _channel._localCloseCode = closeCode;
    _channel._localCloseReason = closeReason;
    return super.close();
  }
}

/// An enum for choosing what type [HtmlWebSocketChannel] emits for binary
/// messages.
class BinaryType {
  /// Tells the channel to emit binary messages as [Blob]s.
  static const blob = BinaryType._('blob', 'blob');

  /// Tells the channel to emit binary messages as [Uint8List]s.
  static const list = BinaryType._('list', 'arraybuffer');

  /// The name of the binary type, which matches its variable name.
  final String name;

  /// The value as understood by the underlying [WebSocket] API.
  final String value;

  const BinaryType._(this.name, this.value);

  @override
  String toString() => name;
}
