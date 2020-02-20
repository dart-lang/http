// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'src/connection.dart';
import 'src/hpack/hpack.dart' show Header;

export 'src/hpack/hpack.dart' show Header;

typedef ActiveStateHandler = void Function(bool isActive);

/// Settings for a [TransportConnection].
abstract class Settings {
  /// The maximum number of concurrent streams the remote end can open
  /// (defaults to being unlimited).
  final int concurrentStreamLimit;

  /// The default stream window size the remote peer can use when creating new
  /// streams (defaults to 65535 bytes).
  final int streamWindowSize;

  const Settings({this.concurrentStreamLimit, this.streamWindowSize});
}

/// Settings for a [TransportConnection] a server can make.
class ServerSettings extends Settings {
  const ServerSettings({int concurrentStreamLimit, int streamWindowSize})
      : super(
            concurrentStreamLimit: concurrentStreamLimit,
            streamWindowSize: streamWindowSize);
}

/// Settings for a [TransportConnection] a client can make.
class ClientSettings extends Settings {
  /// Whether the client allows pushes from the server (defaults to false).
  final bool allowServerPushes;

  const ClientSettings(
      {int concurrentStreamLimit,
      int streamWindowSize,
      this.allowServerPushes = false})
      : super(
            concurrentStreamLimit: concurrentStreamLimit,
            streamWindowSize: streamWindowSize);
}

/// Represents a HTTP/2 connection.
abstract class TransportConnection {
  /// Pings the other end.
  Future ping();

  /// Sets the active state callback.
  ///
  /// This callback is invoked with `true` when the number of active streams
  /// goes from 0 to 1 (the connection goes from idle to active), and with
  /// `false` when the number of active streams becomes 0 (the connection goes
  /// from active to idle).
  set onActiveStateChanged(ActiveStateHandler callback);

  /// Finish this connection.
  ///
  /// No new streams will be accepted or can be created.
  Future finish();

  /// Terminates this connection forcefully.
  Future terminate();
}

abstract class ClientTransportConnection extends TransportConnection {
  factory ClientTransportConnection.viaSocket(Socket socket,
          {ClientSettings settings}) =>
      ClientTransportConnection.viaStreams(socket, socket, settings: settings);

  factory ClientTransportConnection.viaStreams(
      Stream<List<int>> incoming, StreamSink<List<int>> outgoing,
      {ClientSettings settings}) {
    settings ??= const ClientSettings();
    return ClientConnection(incoming, outgoing, settings);
  }

  /// Whether this connection is open and can be used to make new requests
  /// via [makeRequest].
  bool get isOpen;

  /// Creates a new outgoing stream.
  ClientTransportStream makeRequest(List<Header> headers,
      {bool endStream = false});
}

abstract class ServerTransportConnection extends TransportConnection {
  factory ServerTransportConnection.viaSocket(Socket socket,
      {ServerSettings settings}) {
    return ServerTransportConnection.viaStreams(socket, socket,
        settings: settings);
  }

  factory ServerTransportConnection.viaStreams(
      Stream<List<int>> incoming, StreamSink<List<int>> outgoing,
      {ServerSettings settings =
          const ServerSettings(concurrentStreamLimit: 1000)}) {
    settings ??= const ServerSettings();
    return ServerConnection(incoming, outgoing, settings);
  }

  /// Incoming HTTP/2 streams.
  Stream<ServerTransportStream> get incomingStreams;
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

  /// Sets the termination handler on this stream.
  ///
  /// The handler will be called if the stream receives an RST_STREAM frame.
  set onTerminated(void Function(int) value);

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
  void sendHeaders(List<Header> headers, {bool endStream = false}) {
    outgoingMessages.add(HeadersStreamMessage(headers, endStream: endStream));
    if (endStream) outgoingMessages.close();
  }

  void sendData(List<int> bytes, {bool endStream = false}) {
    outgoingMessages.add(DataStreamMessage(bytes, endStream: endStream));
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
abstract class StreamMessage {
  final bool endStream;

  StreamMessage({bool endStream}) : endStream = endStream ?? false;
}

/// Represents a data message which can be sent over a HTTP/2 stream.
class DataStreamMessage extends StreamMessage {
  final List<int> bytes;

  DataStreamMessage(this.bytes, {bool endStream}) : super(endStream: endStream);

  @override
  String toString() => 'DataStreamMessage(${bytes.length} bytes)';
}

/// Represents a headers message which can be sent over a HTTP/2 stream.
class HeadersStreamMessage extends StreamMessage {
  final List<Header> headers;

  HeadersStreamMessage(this.headers, {bool endStream})
      : super(endStream: endStream);

  @override
  String toString() => 'HeadersStreamMessage(${headers.length} headers)';
}

/// Represents a remote stream push.
class TransportStreamPush {
  /// The request headers which [stream] is the response to.
  final List<Header> requestHeaders;

  /// The remote stream push.
  final ClientTransportStream stream;

  TransportStreamPush(this.requestHeaders, this.stream);

  @override
  String toString() =>
      'TransportStreamPush(${requestHeaders.length} request headers headers)';
}

/// An exception thrown by the HTTP/2 implementation.
class TransportException implements Exception {
  final String message;

  TransportException(this.message);

  @override
  String toString() => 'HTTP/2 error: $message';
}

/// An exception thrown when a HTTP/2 connection error occurred.
class TransportConnectionException extends TransportException {
  final int errorCode;

  TransportConnectionException(int errorCode, String details)
      : errorCode = errorCode,
        super('Connection error: $details (errorCode: $errorCode)');
}

/// An exception thrown when a HTTP/2 stream error occured.
class StreamTransportException extends TransportException {
  StreamTransportException(String details) : super('Stream error: $details');
}
