// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import '../web_socket.dart';
import 'utils.dart';
import 'web_socket.dart';

class FakeWebSocket implements WebSocket {
  late FakeWebSocket _other;

  final String _protocol;
  final _events = StreamController<WebSocketEvent>();

  FakeWebSocket(this._protocol);

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
    }

    checkCloseCode(code);
    checkCloseReason(reason);

    unawaited(_events.close());
    if (!_other._events.isClosed) {
      _other._events.add(CloseReceived(code ?? 1005, reason ?? ''));
      unawaited(_other._events.close());
    }
  }

  @override
  Stream<WebSocketEvent> get events => _events.stream;

  @override
  String get protocol => _protocol;

  @override
  void sendBytes(Uint8List b) {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
    }
    if (_other._events.isClosed) return;
    _other._events.add(BinaryDataReceived(b));
  }

  @override
  void sendText(String s) {
    if (_events.isClosed) {
      throw WebSocketConnectionClosed();
    }
    if (_other._events.isClosed) return;
    _other._events.add(TextDataReceived(s));
  }
}

/// Create a pair of fake [WebSocket]s that are connected to each other.
///
/// Sending a message on one [WebSocket] will result in that same message being
/// received by the other.
///
/// This can be useful in constructing tests.
///
/// For example:
///
/// ```dart
/// import 'dart:async';
///
/// import 'package:test/test.dart';
/// import 'package:web_socket/src/web_socket.dart';
/// import 'package:web_socket/testing.dart';
/// import 'package:web_socket/web_socket.dart';
///
/// Future<void> fakeTimeServer(WebSocket webSocket, String time) async {
///   await webSocket.events.forEach((event) {
///     switch (event) {
///       case TextDataReceived():
///       case BinaryDataReceived():
///         webSocket.sendText(time);
///       case CloseReceived():
///     }
///   });
/// }
///
/// Future<DateTime> getTime(WebSocket webSocket) async {
///   webSocket.sendText('');
///   final time = switch (await webSocket.events.first) {
///     TextDataReceived(:final text) => DateTime.parse(text),
///     _ => throw Exception('unexpected response')
///   };
///   await webSocket.close();
///   return time;
/// }
///
/// void main() async {
///   late WebSocket client;
///   late WebSocket server;
///
///   setUp(() {
///     (client, server) = fakes();
///   });
///
///   test('test valid time', () async {
///     unawaited(fakeTimeServer(server, '2024-05-15T01:18:10.456Z'));
///     expect(
///         await getTime(client),
///         DateTime.parse('2024-05-15T01:18:10.456Z'));
///   });
/// }
/// ```
(WebSocket, WebSocket) fakes({String protocol = ''}) {
  final peer1 = FakeWebSocket(protocol);
  final peer2 = FakeWebSocket(protocol);

  peer1._other = peer2;
  peer2._other = peer1;

  return (peer1, peer2);
}
