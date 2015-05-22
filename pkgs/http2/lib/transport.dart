// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.transport;

import 'dart:async';
import 'dart:io';

import 'src/connection.dart';
import 'src/hpack/hpack.dart' show Header;

export 'src/hpack/hpack.dart' show Header;

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

/// Represents a HTTP/2 stream.
abstract class TransportStream {
  // TODO: Populate this class.
}
/// Represents a message which can be sent over a HTTP/2 stream.
abstract class StreamMessage {}


/// Represents a data message which can be sent over a HTTP/2 stream.
class DataStreamMessage implements StreamMessage {
  final List<int> bytes;

  DataStreamMessage(this.bytes);

  String toString() => 'DataStreamMessage(${bytes.length} bytes)';
}


/// Represents a headers message which can be sent over a HTTP/2 stream.
class HeadersStreamMessage implements StreamMessage {
  final List<Header> headers;

  HeadersStreamMessage(this.headers);

  String toString() => 'HeadersStreamMessage(${headers.length} headers)';
}


/// Represents a remote stream push.
class TransportStreamPush {
  /// The request headers which [stream] is the response to.
  final List<Header> requestHeaders;

  /// The remote stream push.
  final TransportStream stream;

  TransportStreamPush(this.requestHeaders, this.stream);

  String toString() =>
      'TransportStreamPush(${requestHeaders.length} request headers headers)';
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
