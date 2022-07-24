// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:stream_channel/stream_channel.dart';

import 'utils_start_server_same_process.dart'
    if (dart.library.html) 'utils_start_server_spawn_process.dart'
    as start_server_impl;

/// Starts a test HTTP server using a relative path name e.g.
/// 'redirect_server.dart' or using the given function.
///
/// When running in the web browser, the path name is used (so that the server
/// runs outside of the browser). Otherwise, the given function is called to
/// start the server in-process.
Future<StreamChannel<Object?>> startServer(String fileName,
        void Function(StreamChannel<Object?> channel) main) async =>
    start_server_impl.startServer(fileName, main);
