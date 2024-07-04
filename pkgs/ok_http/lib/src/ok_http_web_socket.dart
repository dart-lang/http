import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:web_socket/web_socket.dart';

import 'jni/bindings.dart' as bindings;

class OkHttpWebSocket implements WebSocket {
  late bindings.OkHttpClient _client;
  late final bindings.WebSocket _webSocket;
  final _events = StreamController<WebSocketEvent>();
  String? _protocol;

  OkHttpWebSocket._() {
    _client = bindings.WSInterceptor.Companion
        .addWSInterceptor(bindings.OkHttpClient_Builder(),
            bindings.WSInterceptedCallback.implement(
                bindings.$WSInterceptedCallbackImpl(onWS: (req, res) {
      print(req.headers().toString1());
      print(res.headers().toString1());
    }))).build();
  }

  static Future<WebSocket> connect(Uri url,
          {Iterable<dynamic>? protocols}) async =>
      OkHttpWebSocket._()._connect(url, protocols);

  Future<WebSocket> _connect(Uri url, Iterable<dynamic>? protocols) async {
    if (!url.isScheme('ws') && !url.isScheme('wss')) {
      throw ArgumentError.value(
          url, 'url', 'only ws: and wss: schemes are supported');
    }

    final requestBuilder =
        bindings.Request_Builder().url1(url.toString().toJString());

    if (protocols != null) {
      requestBuilder.addHeader('Sec-WebSocket-Protocol'.toJString(),
          protocols.join(', ').toJString());
    }

    var openCompleter = Completer<WebSocket>();

    _client.newWebSocket(
        requestBuilder.build(),
        bindings.WebSocketListenerProxy(
            bindings.WebSocketListenerProxy_WebSocketListener.implement(
                bindings.$WebSocketListenerProxy_WebSocketListenerImpl(
          onOpen: (webSocket, response) {
            _webSocket = webSocket;

            var protocolHeader =
                response.header1('sec-websocket-protocol'.toJString());
            if (!protocolHeader.isNull) {
              _protocol = protocolHeader.toDartString();
              print('$_protocol; $protocols');
              if (!(protocols?.contains(_protocol) ?? true)) {
                openCompleter
                    .completeError(WebSocketException('Protocol mismatch. '
                        'Expected one of $protocols, but received $_protocol'));
                return;
              }
            }

            openCompleter.complete(this);
          },
          onMessage: (bindings.WebSocket webSocket, JString string) {
            if (_events.isClosed) return;
            _events.add(TextDataReceived(string.toDartString()));
          },
          onMessage1:
              (bindings.WebSocket webSocket, bindings.ByteString byteString) {
            if (_events.isClosed) return;
            _events.add(
                BinaryDataReceived(byteString.toByteArray().toUint8List()));
          },
          onClosing:
              (bindings.WebSocket webSocket, int i, JString string) async {
            if (_events.isClosed) throw WebSocketConnectionClosed();

            _events.add(CloseReceived(i, string.toDartString()));
            await _events.close();

            _client.dispatcher().executorService().shutdown();
            _client.connectionPool().evictAll();
            var cache = _client.cache();
            if (!cache.isNull) {
              cache.close();
            }
            _client.release();
          },
          onFailure: (bindings.WebSocket webSocket, JObject throwable,
              bindings.Response response) {
            var throwableString = throwable.toString();
            if (throwableString.contains('java.io.EOFException') ||
                throwableString.contains(
                    // ignore: lines_longer_than_80_chars
                    'java.net.ProtocolException: Control frames must be final.')) {
              _events.add(CloseReceived(1006, 'closed abnormal'));
              unawaited(_events.close());
              return;
            }
            print('problems $throwableString');
            var error = WebSocketException(
                'Connection ended unexpectedly $throwableString');
            if (openCompleter.isCompleted) {
              _events.addError(error);
              return;
            }
            openCompleter.completeError(error);
          },
        ))));

    return openCompleter.future;
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
    }

    if (code != null && code != 1000 && !(code >= 3000 && code <= 4999)) {
      throw ArgumentError('Invalid argument: $code, close code must be 1000 or '
          'in the range 3000-4999');
    }
    if (reason != null && utf8.encode(reason).length > 123) {
      throw ArgumentError.value(reason, 'reason',
          'reason must be <= 123 bytes long when encoded as UTF-8');
    }

    // unawaited(_events.close());

    _webSocket.close(code ?? 1010,
        reason?.toJString() ?? JString.fromReference(jNullReference));
  }

  @override
  Stream<WebSocketEvent> get events => _events.stream;

  @override
  String get protocol => _protocol ?? '';

  @override
  void sendBytes(Uint8List b) {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
    }
    _webSocket.send1(bindings.ByteString.of(b.toJArray()));
  }

  @override
  void sendText(String s) {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
    }
    _webSocket.send(s.toJString());
  }
}

extension on Uint8List {
  JArray<jbyte> toJArray() =>
      JArray(jbyte.type, length)..setRange(0, length, this);
}

extension on JArray<jbyte> {
  Uint8List toUint8List({int? length}) {
    length ??= this.length;
    final list = Uint8List(length);
    for (var i = 0; i < length; i++) {
      list[i] = this[i];
    }
    return list;
  }
}
