// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:stream_channel/stream_channel.dart';

/// Starts a test HTTP server by calling the given function.
Future<StreamChannel<Object?>> startServer(
    String fileName, void Function(StreamChannel<Object?> channel) main) async {
  final controller = StreamChannelController<Object?>(sync: true);
  main(controller.foreign);
  return controller.local;
}
