// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';

/// Starts an HTTP server that captures request headers and any body bytes
/// transferred on the wire.
///
/// Channel protocol:
///    On Startup:
///     - send port
///    On Request Received:
///     - send Map with 'headers' (`Map<String, List<String>>`) and 'body'
///       (`List<int>`)
///    When Receive Anything:
///     - exit
void hybridMain(StreamChannel<Object?> channel) async {
  late ServerSocket server;

  server = (await ServerSocket.bind('localhost', 0))
    ..listen((Socket socket) {
      final buffer = BytesBuilder();
      var responded = false;

      socket.listen(
        (data) {
          buffer.add(data);
          final bytes = buffer.toBytes();
          final headerEnd = _findHeaderEnd(bytes);

          if (headerEnd != -1 && !responded) {
            final headerText = ascii.decode(bytes.sublist(0, headerEnd));
            final requestLine = headerText.split('\r\n').first;
            final method = requestLine.split(' ').first;

            if (method == 'OPTIONS') {
              responded = true;
              socket.write(
                'HTTP/1.1 200 OK\r\n'
                'Access-Control-Allow-Origin: *\r\n'
                'Access-Control-Allow-Methods: GET, HEAD, OPTIONS\r\n'
                'Access-Control-Allow-Headers: *\r\n'
                'Content-Length: 0\r\n\r\n',
              );
              unawaited(socket.close());
              return;
            }

            responded = true;
            final headers = _parseHeaders(headerText);
            socket.write(
              'HTTP/1.1 200 OK\r\n'
              'Access-Control-Allow-Origin: *\r\n'
              'Content-Length: 0\r\n\r\n',
            );
            Future.delayed(const Duration(milliseconds: 100), () {
              final allBytes = buffer.toBytes();
              final body = allBytes.sublist(headerEnd);
              channel.sink.add({
                'headers': headers,
                'body': body.toList(),
              });
              unawaited(socket.close());
            });
          }
        },
        onError: (Object _) {},
        cancelOnError: true,
      );
    });

  channel.sink.add(server.port);
  await channel
      .stream.first; // Any writes indicates that the server should exit.
  unawaited(server.close());
}

int _findHeaderEnd(List<int> bytes) {
  for (var i = 0; i < bytes.length - 3; i++) {
    if (bytes[i] == 13 &&
        bytes[i + 1] == 10 &&
        bytes[i + 2] == 13 &&
        bytes[i + 3] == 10) {
      return i + 4;
    }
  }
  return -1;
}

Map<String, List<String>> _parseHeaders(String headerString) {
  final lines = const LineSplitter().convert(headerString);
  final headers = <String, List<String>>{};
  for (var i = 1; i < lines.length; ++i) {
    final line = lines[i];
    if (line.isEmpty) break;
    final colonIndex = line.indexOf(':');
    if (colonIndex != -1) {
      final key = line.substring(0, colonIndex).trim().toLowerCase();
      final value = line.substring(colonIndex + 1).trim();
      headers.putIfAbsent(key, () => []).add(value);
    }
  }
  return headers;
}
