// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2;

import 'dart:async';
import 'dart:io';

import 'src/connection.dart';

/// Represents a HTTP/2 connection.
abstract class TransportConnection {
  factory TransportConnection.clientViaSocket(Socket socket)
      => new TransportConnection.clientViaStreams(socket, socket);

  factory TransportConnection.serverViaSocket(Socket socket)
      => new TransportConnection.serverViaStreams(socket, socket);

  factory TransportConnection.clientViaStreams(Stream<List<int>> incoming,
                                               Sink<List<int>> outgoing)
      => new Connection.client(incoming, outgoing);

  factory TransportConnection.serverViaStreams(Stream<List<int>> incoming,
                                               Sink<List<int>> outgoing)
      => new Connection.server(incoming, outgoing);

  /// Pings the other end.
  Future ping();

  /// Finish this connection.
  ///
  /// No new streams will be accepted or can be created.
  void finish();

  /// Terminates this connection forcefully.
  Future terminate();
}

/// An exception thrown by the HTTP/2 implementation.
class TransportException implements Exception {
  final String message;

  TransportException(this.message);

  String toString() => 'HTTP/2 error: $message';
}

/// An exception thrown when a HTTP/2 connection error occurred.
class TransportConnectionException extends TransportException {
  final int errorCode;

  TransportConnectionException(this.errorCode, String details)
      : super('Connection error: $details');
}
