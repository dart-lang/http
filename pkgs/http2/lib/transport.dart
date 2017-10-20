// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This library provides an http/2 interface on top of a bidirectional stream
/// of bytes.
///
/// The client and server sides can be created via [ClientTransportStream] and
/// [ServerTransportStream] respectively. Both sides can be configured via
/// settings (see [ClientSettings] and [ServerSettings]). The settings will be
/// communicated to the remote peer (if necessary) and will be valid during the
/// entire lifetime of the connection.
///
/// A http/2 transport allows a client to open a bidirectional stream (see
/// [ClientTransportConnection.makeRequest]) and a server can open (or push) a
/// unidirectional stream to the client via [ServerTransportStream.push].
///
/// In both cases (unidirectional and bidirectional stream), one can send
/// headers and data to the other side (via [HeadersStreamMessage] and
/// [DataStreamMessage]). These messages are ordered and will arrive in the same
/// order as they were sent (data messages may be split up into multiple smaller
/// chunks or might be combined).
///
/// In the most common case, each direction will send one [HeadersStreamMessage]
/// followed by zero or more [DataStreamMessage]s.
///
/// Establishing a bidirectional stream of bytes to a server is up to the user
/// of this library. There are 3 common ways to achive this
///
///     * connect to a server via SSL and use the ALPN (SSL) protocol extension
///       to negogiate with the server to speak http/2 (the ALPN protocol
///       identifier for http/2 is `h2`)
///
///     * have prior knowledge about the server - i.e. know ahead of time that
///       the server will speak http/2 via an unencrypted tcp connection
///
///     * use a http/1.1 connection and upgrade it to http/2
///
/// The first way is the most common way and can be done in Dart by using
/// `dart:io`s secure socket implementation (by using a `SecurityContext` and
/// including 'h2' in the list of protocols used for ALPN).
///
/// Here is a simple example on how to connect to a http/2 capable server and
/// requesting a resource:
///
///     import 'dart:async';
///     import 'dart:convert';
///     import 'dart:io';
///
///     import 'package:http2/transport.dart';
///
///     main() async {
///       var uri = Uri.parse("https://www.google.com/");
///
///       var socket = await connect(uri);
///
///       // The default client settings will disable server pushes. We
///       // therefore do not need to deal with [stream.peerPushes].
///       var transport = new ClientTransportConnection.viaSocket(socket);
///
///       var headers = [
///         new Header.ascii(':method', 'GET'),
///         new Header.ascii(':path', uri.path),
///         new Header.ascii(':scheme', uri.scheme),
///         new Header.ascii(':authority', uri.host),
///       ];
///
///       var stream = transport.makeRequest(headers, endStream: true);
///       await for (var message in stream.incomingMessages) {
///         if (message is HeadersStreamMessage) {
///           for (var header in message.headers) {
///             var name = UTF8.decode(header.name);
///             var value = UTF8.decode(header.value);
///             print('$name: $value');
///           }
///         } else if (message is DataStreamMessage) {
///           // Use [message.bytes] (but respect 'content-encoding' header)
///         }
///       }
///       await transport.finish();
///     }
///
///     Future<Socket> connect(Uri uri) async {
///       bool useSSL = uri.scheme == 'https';
///       if (useSSL) {
///         var secureSocket = await SecureSocket.connect(
///             uri.host, uri.port, supportedProtocols: ['h2']);
///         if (secureSocket.selectedProtocol != 'h2') {
///           throw new Exception(
///               "Failed to negogiate http/2 via alpn. Maybe server "
///               "doesn't support http/2.");
///         }
///         return secureSocket;
///       } else {
///         return await Socket.connect(uri.host, uri.port);
///       }
///     }
///
library http2.transport;

import 'dart:async';
import 'dart:io';

import 'src/connection.dart';
import 'src/hpack/hpack.dart' show Header;

export 'src/hpack/hpack.dart' show Header;

typedef void ActiveStateHandler(bool isActive);

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
      this.allowServerPushes: false})
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
  /// This callback is invoked with [true] when the number of active streams
  /// goes from 0 to 1 (the connection goes from idle to active), and with
  /// [false] when the number of active streams becomes 0 (the connection goes
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
      new ClientTransportConnection.viaStreams(socket, socket,
          settings: settings);

  factory ClientTransportConnection.viaStreams(
      Stream<List<int>> incoming, StreamSink<List<int>> outgoing,
      {ClientSettings settings}) {
    if (settings == null) settings = const ClientSettings();
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
    return new ServerTransportConnection.viaStreams(socket, socket,
        settings: settings);
  }

  factory ServerTransportConnection.viaStreams(
      Stream<List<int>> incoming, StreamSink<List<int>> outgoing,
      {ServerSettings settings:
          const ServerSettings(concurrentStreamLimit: 1000)}) {
    if (settings == null) settings = const ServerSettings();
    return new ServerConnection(incoming, outgoing, settings);
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
  set onTerminated(void value(int v));

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
    outgoingMessages
        .add(new HeadersStreamMessage(headers, endStream: endStream));
    if (endStream) outgoingMessages.close();
  }

  void sendData(List<int> bytes, {bool endStream: false}) {
    outgoingMessages.add(new DataStreamMessage(bytes, endStream: endStream));
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

  StreamMessage({bool endStream}) : this.endStream = endStream ?? false;
}

/// Represents a data message which can be sent over a HTTP/2 stream.
class DataStreamMessage extends StreamMessage {
  final List<int> bytes;

  DataStreamMessage(this.bytes, {bool endStream}) : super(endStream: endStream);

  String toString() => 'DataStreamMessage(${bytes.length} bytes)';
}

/// Represents a headers message which can be sent over a HTTP/2 stream.
class HeadersStreamMessage extends StreamMessage {
  final List<Header> headers;

  HeadersStreamMessage(this.headers, {bool endStream})
      : super(endStream: endStream);

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

  TransportConnectionException(int errorCode, String details)
      : errorCode = errorCode,
        super('Connection error: $details (errorCode: $errorCode)');
}

/// An exception thrown when a HTTP/2 stream error occured.
class StreamTransportException extends TransportException {
  StreamTransportException(String details) : super('Stream error: $details');
}
