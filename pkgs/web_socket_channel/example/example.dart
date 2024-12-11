// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  final wsUrl = Uri.parse('ws://example.com');
  final channel = WebSocketChannel.connect(wsUrl);

  await channel.ready;

  channel.stream.listen((message) {
    channel.sink.add('received!');
    channel.sink.close(status.goingAway);
  });
}
