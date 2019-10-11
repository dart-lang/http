// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:web_socket_channel/html.dart';

import '../web_socket_channel.dart';

/// Creates a new WebSocket connection.
///
/// Connects to [uri] using and returns a channel that can be used to
/// communicate over the resulting socket.
WebSocketChannel connect(Uri uri) => HtmlWebSocketChannel.connect(uri);
