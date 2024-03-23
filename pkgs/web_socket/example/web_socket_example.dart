import 'dart:convert';
import 'dart:io';

import 'package:web_socket/web_socket.dart';

const requestId = 305;

/// Prints the US dollar value of Bitcoins continuously.
void main() async {
  // Whitebit public WebSocket API documentation:
  // https://docs.whitebit.com/public/websocket/
  final socket =
      await WebSocket.connect(Uri.parse('wss://api.whitebit.com/ws'));

  socket.events.listen((e) {
    switch (e) {
      case TextDataReceived(text: final text):
        final json = jsonDecode(text) as Map;
        if (json['id'] == requestId) {
          if (json['error'] != null) {
            stderr.writeln('Failure: ${json['error']}');
            socket.close();
          }
        } else {
          final params = (json['params'] as List).cast<List<dynamic>>();
          print('₿1 = USD\$${params[0][2]}');
        }
      case BinaryDataReceived():
        stderr.writeln('Unexpected binary response from server');
        socket.close();
      case CloseReceived():
        stderr.writeln('Connection to server closed');
    }
  });
  socket.sendText(jsonEncode({
    'id': requestId,
    'method': 'candles_subscribe',
    'params': ['BTC_USD', 5]
  }));
}
