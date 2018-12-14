// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
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
///       to negotiate with the server to speak http/2 (the ALPN protocol
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
/// A simple example on how to connect to a http/2 capable server and
/// requesting a resource is available at https://github.com/dart-lang/http2/blob/master/example/display_headers.dart.
library http2.http2;

import 'transport.dart';
export 'transport.dart';
