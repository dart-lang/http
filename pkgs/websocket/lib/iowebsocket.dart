import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:websocket/websocket.dart';

class IOWebSocket implements XXXWebSocket {
  final io.WebSocket _webSocket;
  final _events = StreamController<WebSocketEvent>();

  static Future<IOWebSocket> connect(Uri uri) async {
    try {
      final webSocket = await io.WebSocket.connect(uri.toString());
      return IOWebSocket._(webSocket);
    } on io.WebSocketException catch (e) {
      print(e.message);
      throw XXXWebSocketException(e.message);
    }
  }

  IOWebSocket._(this._webSocket) {
    _webSocket.listen(
      (event) {
        print('event: $event');
        switch (event) {
          case String e:
            _events.add(TextDataReceived(e));
          case List<int> e:
            _events.add(BinaryDataReceived(Uint8List.fromList(e)));
        }
      },
      onError: (e, st) {
        final wse = switch (e) {
          io.WebSocketException(message: final message) =>
            XXXWebSocketException(message),
          _ => XXXWebSocketException(),
        };
        _events.addError(wse, st);
      },
      onDone: () {
        print('onDone');
        if (!_events.isClosed) {
          _events.add(CloseReceived(
              _webSocket.closeCode, _webSocket.closeReason ?? ""));
          _events.close();
        }
      },
    );
  }

  // JS: Silently discards data if connection is closed.
  @override
  void sendBytes(Uint8List b) {
    if (_events.isClosed) {
      throw StateError('WebSocket is closed');
    }
    _webSocket.add(b);
  }

  @override
  void sendText(String s) {
    if (_events.isClosed) {
      throw StateError('WebSocket is closed');
    }
    _webSocket.add(s);
  }

  /// Closes the stream.
  /// https://datatracker.ietf.org/doc/html/rfc6455#section-5.5.1
  /// Cannot send more data after this.

  //  If an endpoint receives a Close frame and did not previously send a
  //  Close frame, the endpoint MUST send a Close frame in response.  (When
  //  sending a Close frame in response, the endpoint typically echos the
  //  status code it received.)  It SHOULD do so as soon as practical.  An
  //  endpoint MAY delay sending a Close frame until its current message is
  //  sent (for instance, if the majority of a fragmented message is
  //  already sent, an endpoint MAY send the remaining fragments before
  //  sending a Close frame).  However, there is no guarantee that the
  //  endpoint that has already sent a Close frame will continue to process
  //  data.
  @override
  Future<void> close([int? code, String? reason]) async {
    if (_events.isClosed) {
      throw XXXWebSocketConnectionClosed();
    }

    if (code != null) {
      RangeError.checkValueInInterval(code, 3000, 4999, 'code');
    }
    if (reason != null && utf8.encode(reason).length > 123) {
      throw ArgumentError.value(reason, "reason",
          "reason must be <= 123 bytes long when encoded as UTF-8");
    }

    unawaited(_events.close());
    try {
      await _webSocket.close(code, reason);
    } on io.WebSocketException catch (e) {
      throw XXXWebSocketException(e.message);
    }
  }

  @override
  Stream<WebSocketEvent> get events => _events.stream;
}
