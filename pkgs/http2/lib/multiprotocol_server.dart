// Copyright (c) 2016 the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'src/artificial_server_socket.dart';
import 'transport.dart' as http2;

/// Handles protocol negotiation with HTTP/1.1 and HTTP/2 clients.
///
/// Given a (host, port) pair and a [SecurityContext], [MultiProtocolHttpServer]
/// will negotiate with the client whether HTTP/1.1 or HTTP/2 should be spoken.
///
/// The user must supply 2 callback functions to [startServing], which:
///   * one handles HTTP/1.1 clients (called with a [HttpRequest])
///   * one handles HTTP/2 clients (called with a [http2.ServerTransportStream])
class MultiProtocolHttpServer {
  final SecureServerSocket _serverSocket;
  final http2.ServerSettings _settings;

  _ServerSocketController _http11Controller;
  HttpServer _http11Server;

  StreamController<http2.ServerTransportStream> _http2Controller;
  Stream<http2.ServerTransportStream> _http2Server;
  final _http2Connections = <http2.ServerTransportConnection>{};

  MultiProtocolHttpServer._(this._serverSocket, this._settings) {
    _http11Controller =
        _ServerSocketController(_serverSocket.address, _serverSocket.port);
    _http11Server = HttpServer.listenOn(_http11Controller.stream);

    _http2Controller = StreamController();
    _http2Server = _http2Controller.stream;
  }

  /// Binds a new [SecureServerSocket] with a security [context] at [port] and
  /// [address] (see [SecureServerSocket.bind] for a description of supported
  /// types for [address]).
  ///
  /// Optionally [settings] can be supplied which will be used for HTTP/2
  /// clients.
  ///
  /// See also [startServing].
  static Future<MultiProtocolHttpServer> bind(
      address, int port, SecurityContext context,
      {http2.ServerSettings settings}) async {
    context.setAlpnProtocols(['h2', 'h2-14', 'http/1.1'], true);
    var secureServer = await SecureServerSocket.bind(address, port, context);
    return MultiProtocolHttpServer._(secureServer, settings);
  }

  /// The port this multi-protocol HTTP server runs on.
  int get port => _serverSocket.port;

  /// The address this multi-protocol HTTP server runs on.
  InternetAddress get address => _serverSocket.address;

  /// Starts listening for HTTP/1.1 and HTTP/2 clients and calls the given
  /// callbacks for new clients.
  ///
  /// It is expected that [callbackHttp11] and [callbackHttp2] will never throw
  /// an exception (i.e. these must take care of error handling themselves).
  void startServing(void Function(HttpRequest) callbackHttp11,
      void Function(http2.ServerTransportStream) callbackHttp2,
      {void Function(dynamic error, StackTrace) onError}) {
    // 1. Start listening on the real [SecureServerSocket].
    _serverSocket.listen((SecureSocket socket) {
      var protocol = socket.selectedProtocol;
      if (protocol == null || protocol == 'http/1.1') {
        _http11Controller.addHttp11Socket(socket);
      } else if (protocol == 'h2' || protocol == 'h2-14') {
        var connection = http2.ServerTransportConnection.viaSocket(socket,
            settings: _settings);
        _http2Connections.add(connection);
        connection.incomingStreams.listen(_http2Controller.add,
            onError: onError,
            onDone: () => _http2Connections.remove(connection));
      } else {
        socket.destroy();
        throw Exception('Unexpected negotiated ALPN protocol: $protocol.');
      }
    }, onError: onError);

    // 2. Drain all incoming http/1.1 and http/2 connections and call the
    // respective handlers.
    _http11Server.listen(callbackHttp11);
    _http2Server.listen(callbackHttp2);
  }

  /// Closes this [MultiProtocolHttpServer].
  ///
  /// Completes once everything has been successfully shut down.
  Future close({bool force = false}) {
    return _serverSocket.close().whenComplete(() {
      var done1 = _http11Server.close(force: force);
      Future done2 = Future.wait(
          _http2Connections.map((c) => force ? c.terminate() : c.finish()));
      return Future.wait([done1, done2]);
    });
  }
}

/// An internal helper class.
class _ServerSocketController {
  final InternetAddress address;
  final int port;
  final StreamController<Socket> _controller = StreamController();

  _ServerSocketController(this.address, this.port);

  ArtificialServerSocket get stream {
    return ArtificialServerSocket(address, port, _controller.stream);
  }

  void addHttp11Socket(Socket socket) {
    _controller.add(socket);
  }

  Future close() => _controller.close();
}
