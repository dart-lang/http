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
  /// Pings the other end.
  Future ping();

  /// Finish this connection.
  ///
  /// No new streams will be accepted or can be created.
  void finish();

  /// Terminates this connection forcefully.
  Future terminate();
}

abstract class ClientTransportConnection extends TransportConnection {
  factory ClientTransportConnection.viaSocket(Socket socket,
                                              {bool allowServerPushes: true})
      => new ClientTransportConnection.viaStreams(
          socket, socket, allowServerPushes: allowServerPushes);

  factory ClientTransportConnection.viaStreams(Stream<List<int>> incoming,
                                               Sink<List<int>> outgoing,
                                               {bool allowServerPushes: true})
      => new ClientConnection(
          incoming, outgoing, allowServerPushes: allowServerPushes);

  /// Creates a new outgoing stream.
  ClientTransportStream makeRequest(List<Header> headers,
                                    {bool endStream: false});
}

abstract class ServerTransportConnection extends TransportConnection {
  factory ServerTransportConnection.viaSocket(Socket socket)
      => new ServerTransportConnection.viaStreams(socket, socket);

  factory ServerTransportConnection.viaStreams(Stream<List<int>> incoming,
                                                     Sink<List<int>> outgoing)
      => new ServerConnection(incoming, outgoing);

  /// Incoming HTTP/2 streams.
  Stream<TransportStream> get incomingStreams;

  /// Finish this connection.
  ///
  /// No new streams will be accepted or can be created.
  void finish();

  /// Terminates this connection forcefully.
  Future terminate();
}

/// Represents a HTTP/2 stream.
abstract class TransportStream {
  /// The id of this stream.
  ///
  ///   * odd numbered streams are client streams
  ///   * even numbered streams are opened from the server
  int get id;

  /// A stream of data and/or headers from the remote end.
  Stream<StreamMessage> get incomingMessages;

  /// A sink for writing data and/or headers to the remote end.
  StreamSink<StreamMessage> get outgoingMessages;

  /// Terminates this HTTP/2 stream in an un-normal way.
  ///
  /// For normal termination, one can cancel the [StreamSubscription] from
  /// `incoming.listen()` and close the `outgoing` [StreamSink].
  ///
  /// Terminating this HTTP/2 stream will free up all resources associated with
  /// it locally and will notify the remote end that this stream is no longer
  /// used.
  void terminate();

  // For convenience only.
  void sendHeaders(List<Header> headers, {bool endStream: false}) {
    outgoingMessages.add(new HeadersStreamMessage(headers));
    if (endStream) outgoingMessages.close();
  }

  void sendData(List<int> bytes, {bool endStream: false}) {
    outgoingMessages.add(new DataStreamMessage(bytes));
    if (endStream) outgoingMessages.close();
  }
}

abstract class ClientTransportStream extends TransportStream {
  /// Streams which the remote end pushed to this endpoint.
  Stream<TransportStreamPush> get peerPushes;
}

abstract class ServerTransportStream extends TransportStream {
  /// Pushes a new stream to the remote peer.
  TransportStream push(List<Header> requestHeaders);
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

/// An exception thrown when a HTTP/2 connection error occured.
class StreamTransportException extends TransportException {
  StreamTransportException(String details)
      : super('Stream error: $details');
}
