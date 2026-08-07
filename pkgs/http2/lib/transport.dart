// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'src/connection.dart';
import 'src/hpack/hpack.dart' show Header;

export 'src/frames/frames.dart' show ErrorCode;
export 'src/hpack/hpack.dart' show Header;

typedef ActiveStateHandler = void Function(bool isActive);

/// Default maximum number of peer-initiated streams per connection.
///
/// A limit of 100 follows the lower bound recommended by
/// [RFC 9113 section 6.5.2](https://www.rfc-editor.org/rfc/rfc9113.html#section-6.5.2),
/// avoiding an unnecessarily restrictive default while bounding per-stream
/// state.
const int defaultMaxConcurrentStreams = 100;

/// Default maximum compressed size of one inbound HTTP/2 field block.
///
/// 16 KiB matches the protocol's initial maximum frame payload size from
/// [RFC 9113 section 4.1](https://www.rfc-editor.org/rfc/rfc9113.html#section-4.1).
/// This bounds fragmented field-block buffering to the byte budget of one
/// default-sized frame.
const int defaultMaxInboundHeaderBlockSize = 16 * 1024;

/// Default maximum decoded size of one inbound HTTP/2 field section.
///
/// 8 KiB is a conservative application-visible budget that bounds HPACK
/// amplification before headers reach application code. The field-size
/// accounting follows
/// [RFC 9113 section 6.5.2](https://www.rfc-editor.org/rfc/rfc9113.html#section-6.5.2).
const int defaultMaxInboundHeaderListSize = 8 * 1024;

/// Default absolute time allowed to finish an inbound HTTP/2 field block.
///
/// Ten seconds allows for ordinary network delay while bounding how long a
/// slow peer can retain field-block and HPACK processing state.
const Duration defaultInboundHeaderBlockTimeout = Duration(seconds: 10);

/// Default maximum number of CONTINUATION frames in one field block.
///
/// The byte limit alone does not bound floods of empty or very small frames.
/// 16 still permits a 16 KiB block to be split into fragments averaging 1 KiB
/// while placing a finite bound on per-frame processing, addressing the class
/// of issue described by [CERT VU#421644](https://kb.cert.org/vuls/id/421644).
const int defaultMaxContinuationFramesPerBlock = 16;

/// Default number of consecutive peer stream-limit violations before GOAWAY.
///
/// Once the peer has acknowledged the advertised stream limit, eight tolerates
/// a short burst of racing streams while still terminating a peer that
/// repeatedly ignores the limit. Accepting a peer stream resets the violation
/// count.
const int defaultMaxPeerStreamLimitViolations = 8;

/// Settings for a [TransportConnection].
abstract class Settings {
  /// The maximum number of concurrent streams the remote end can open
  /// (defaults to [defaultMaxConcurrentStreams]).
  ///
  /// This limit is advertised and enforced locally. Set to `null` to make the
  /// number of peer-initiated streams unlimited. Reserved peer streams are
  /// included in the local allocation guard even though the HTTP/2 setting
  /// counts only open and half-closed streams.
  final int? concurrentStreamLimit;

  /// The default stream window size the remote peer can use when creating new
  /// streams (defaults to 65535 bytes).
  final int? streamWindowSize;

  /// Maximum compressed bytes retained for one inbound field block.
  ///
  /// This is a local enforcement limit and is not advertised to the peer.
  /// Set to `null` to disable the limit.
  final int? maxInboundHeaderBlockSize;

  /// Maximum decoded size of one inbound field section.
  ///
  /// The size is the sum of `name.length + value.length + 32` for every field.
  /// This value is both advertised with SETTINGS_MAX_HEADER_LIST_SIZE and
  /// enforced locally. Set to `null` to disable both behaviors.
  final int? maxInboundHeaderListSize;

  /// Absolute time allowed to receive a complete inbound field block.
  ///
  /// The timer starts as soon as the initial HEADERS or PUSH_PROMISE frame
  /// header is parsed, before its payload is buffered. It is not extended by
  /// CONTINUATION frames and ends only after the final frame is fully read.
  /// Set to `null` to disable the timeout.
  final Duration? inboundHeaderBlockTimeout;

  /// Maximum number of CONTINUATION frames accepted for one field block.
  ///
  /// Set to `null` to disable the frame-count limit.
  final int? maxContinuationFramesPerBlock;

  /// Consecutive peer stream-limit violations allowed before terminating the
  /// connection with ENHANCE_YOUR_CALM.
  ///
  /// Individual violations are rejected with REFUSED_STREAM. The counter is
  /// incremented only after the peer acknowledges the advertised stream limit
  /// and is reset after a peer-initiated stream is accepted. Set to `null` to
  /// never terminate the connection based only on this violation count.
  final int? maxPeerStreamLimitViolations;

  const Settings({
    this.concurrentStreamLimit,
    this.streamWindowSize,
    this.maxInboundHeaderBlockSize,
    this.maxInboundHeaderListSize,
    this.inboundHeaderBlockTimeout,
    this.maxContinuationFramesPerBlock,
    this.maxPeerStreamLimitViolations,
  });
}

/// Settings for a [TransportConnection] a server can make.
class ServerSettings extends Settings {
  const ServerSettings({
    super.concurrentStreamLimit = defaultMaxConcurrentStreams,
    super.streamWindowSize,
    super.maxInboundHeaderBlockSize = defaultMaxInboundHeaderBlockSize,
    super.maxInboundHeaderListSize = defaultMaxInboundHeaderListSize,
    super.inboundHeaderBlockTimeout = defaultInboundHeaderBlockTimeout,
    super.maxContinuationFramesPerBlock = defaultMaxContinuationFramesPerBlock,
    super.maxPeerStreamLimitViolations = defaultMaxPeerStreamLimitViolations,
  });
}

/// Settings for a [TransportConnection] a client can make.
class ClientSettings extends Settings {
  /// Whether the client allows pushes from the server (defaults to false).
  final bool allowServerPushes;

  const ClientSettings({
    super.concurrentStreamLimit = defaultMaxConcurrentStreams,
    super.streamWindowSize,
    super.maxInboundHeaderBlockSize = defaultMaxInboundHeaderBlockSize,
    super.maxInboundHeaderListSize = defaultMaxInboundHeaderListSize,
    super.inboundHeaderBlockTimeout = defaultInboundHeaderBlockTimeout,
    super.maxContinuationFramesPerBlock = defaultMaxContinuationFramesPerBlock,
    super.maxPeerStreamLimitViolations = defaultMaxPeerStreamLimitViolations,
    this.allowServerPushes = false,
  });
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

  /// Future which completes when the first SETTINGS frame is received from
  /// the peer.
  Future<void> get onInitialPeerSettingsReceived;

  /// Stream which emits an event with the ping id every time a ping is received
  /// on this connection.
  Stream<int> get onPingReceived;

  /// Stream which emits an event every time a ping is received on this
  /// connection.
  Stream<void> get onFrameReceived;

  /// Finish this connection.
  ///
  /// No new streams will be accepted or can be created.
  Future finish();

  /// Terminates this connection forcefully.
  Future terminate([int? errorCode, String? message]);
}

abstract class ClientTransportConnection extends TransportConnection {
  factory ClientTransportConnection.viaSocket(
    Socket socket, {
    ClientSettings? settings,
  }) =>
      ClientTransportConnection.viaStreams(socket, socket, settings: settings);

  factory ClientTransportConnection.viaStreams(
    Stream<List<int>> incoming,
    StreamSink<List<int>> outgoing, {
    ClientSettings? settings,
  }) {
    settings ??= const ClientSettings();
    return ClientConnection(incoming, outgoing, settings);
  }

  /// Whether this connection is open and can be used to make new requests
  /// via [makeRequest].
  bool get isOpen;

  /// Creates a new outgoing stream.
  ClientTransportStream makeRequest(
    List<Header> headers, {
    bool endStream = false,
  });
}

abstract class ServerTransportConnection extends TransportConnection {
  factory ServerTransportConnection.viaSocket(
    Socket socket, {
    ServerSettings? settings,
  }) {
    return ServerTransportConnection.viaStreams(
      socket,
      socket,
      settings: settings,
    );
  }

  factory ServerTransportConnection.viaStreams(
    Stream<List<int>> incoming,
    StreamSink<List<int>> outgoing, {
    ServerSettings? settings = const ServerSettings(),
  }) {
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
  set onTerminated(void Function(int?) value);

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

  StreamMessage({bool? endStream}) : endStream = endStream ?? false;
}

/// Represents a data message which can be sent over a HTTP/2 stream.
class DataStreamMessage extends StreamMessage {
  final List<int> bytes;

  DataStreamMessage(this.bytes, {super.endStream});

  @override
  String toString() => 'DataStreamMessage(${bytes.length} bytes)';
}

/// Represents a headers message which can be sent over a HTTP/2 stream.
class HeadersStreamMessage extends StreamMessage {
  final List<Header> headers;

  HeadersStreamMessage(this.headers, {super.endStream});

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

  TransportConnectionException(this.errorCode, String details)
    : super('Connection error: $details (errorCode: $errorCode)');
}

/// An exception thrown when a HTTP/2 stream error occured.
class StreamTransportException extends TransportException {
  StreamTransportException(String details) : super('Stream error: $details');
}
