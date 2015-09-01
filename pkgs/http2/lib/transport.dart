// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.transport;

import 'dart:async';
import 'dart:io';

import 'src/connection.dart';
import 'src/hpack/hpack.dart' show Header;

export 'src/hpack/hpack.dart' show Header;

/// Settings for a [TransportConnection].
abstract class Settings {
  /// The maximum number of concurrent streams the remote end can open.
  final int concurrentStreamLimit;

  const Settings(this.concurrentStreamLimit);
}

/// Settings for a [TransportConnection] a server can make.
class ServerSettings extends Settings {
  const ServerSettings(int concurrentStreamLimit)
      : super(concurrentStreamLimit);
}

/// Settings for a [TransportConnection] a client can make.
class ClientSettings extends Settings {
  /// Whether the client allows pushes from the server.
  final bool allowServerPushes;

  const ClientSettings(int concurrentStreamLimit, this.allowServerPushes)
      : super(concurrentStreamLimit);
}

/// Represents a HTTP/2 connection.
abstract class TransportConnection {
  /// Pings the other end.
  Future ping();

  /// Finish this connection.
  ///
  /// No new streams will be accepted or can be created.
  Future finish();

  /// Terminates this connection forcefully.
  Future terminate();
}

abstract class ClientTransportConnection extends TransportConnection {
  factory ClientTransportConnection.viaSocket(Socket socket,
                                              {ClientSettings settings})
      => new ClientTransportConnection.viaStreams(
          socket, socket, settings: settings);

  factory ClientTransportConnection.viaStreams(
      Stream<List<int>> incoming,
      StreamSink<List<int>> outgoing,
      {ClientSettings settings}) {
    if (settings == null) settings = const ClientSettings(null, false);
    return new ClientConnection(incoming, outgoing, settings);
  }

  /// Whether this connection is open and can be used to make new requests
  /// via [makeRequest].
  bool get isOpen;

  /// Creates a new outgoing stream.
  ClientTransportStream makeRequest(List<Header> headers,
                                    {bool endStream: false});
}

abstract class ServerTransportConnection extends TransportConnection {
  factory ServerTransportConnection.viaSocket(Socket socket,
                                              {ServerSettings settings}) {
    return new ServerTransportConnection.viaStreams(
        socket, socket, settings: settings);
  }

  factory ServerTransportConnection.viaStreams(
      Stream<List<int>> incoming,
      StreamSink<List<int>> outgoing,
      {ServerSettings settings: const ServerSettings(1000)}) {
    if (settings == null) settings = const ServerSettings(null);
    return new ServerConnection(incoming, outgoing, settings);
  }

  /// Incoming HTTP/2 streams.
  Stream<TransportStream> get incomingStreams;
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
  ///
  /// If peer pushes were enabled, the client is responsible to either
  /// handle or reject any peer push.
  Stream<TransportStreamPush> get peerPushes;
}

abstract class ServerTransportStream extends TransportStream {
  /// Whether a method to [push] will succeed. Requirements for this getter to
  /// return `true` are:
  ///    * this stream must be in the Open or HalfClosedRemote state
  ///    * the client needs to have the "enable push" settings enabled
  ///    * the number of active streams has not reached the maximum
  bool get canPush;

  /// Pushes a new stream to the remote peer.
  ServerTransportStream push(List<Header> requestHeaders);
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
  final ClientTransportStream stream;

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
