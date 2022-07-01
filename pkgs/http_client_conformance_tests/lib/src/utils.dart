// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// Starts a test server using a relative path name e.g.
/// 'redirect_server.dart'.
///
/// See [spawnHybridUri].
Future<StreamChannel<Object?>> startServer(String fileName) async =>
    spawnHybridUri(Uri(
        scheme: 'package',
        path: 'http_client_conformance_tests/src/$fileName'));
