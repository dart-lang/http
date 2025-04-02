// Copyright (c) 2016 the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

/// Custom implementation of the [ServerSocket] interface.
///
/// This class can be used to create a [ServerSocket] using [Stream<Socket>] and
/// a [InternetAddress] and `port` (an example use case is to filter [Socket]s
/// and keep the [ServerSocket] interface for APIs that expect it,
/// e.g. `new HttpServer.listenOn()`).
class ArtificialServerSocket extends StreamView<Socket>
    implements ServerSocket {
  ArtificialServerSocket(this.address, this.port, Stream<Socket> stream)
      : super(stream);

  // ########################################################################
  // These are the methods of [ServerSocket] in addition to [Stream<Socket>].
  // ########################################################################

  @override
  final InternetAddress address;

  @override
  final int port;

  /// Closing of an [ArtificialServerSocket] is not possible and an exception
  /// will be thrown when calling this method.
  @override
  Future<ServerSocket> close() async {
    throw Exception('Did not expect close() to be called.');
  }
}
