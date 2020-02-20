// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show ascii;
import 'dart:io';

import '../../transport.dart';

class Request {
  final String method;
  final Uri uri;

  Request(this.method, this.uri);
}

class Response {
  final Map<String, List<String>> headers;
  final Stream<List<int>> stream;
  final Stream<ServerPush> serverPushes;

  Response(this.headers, this.stream, this.serverPushes);
}

class ServerPush {
  final Map<String, List<String>> requestHeaders;
  final Future<Response> response;

  ServerPush(this.requestHeaders, this.response);
}

class ClientConnection {
  final ClientTransportConnection connection;

  /// Assumes the protocol on [socket] was negogiated to be http/2.
  ///
  /// If [settings] are omitted, the default [ClientSettings] will be used.
  ClientConnection(Socket socket, {ClientSettings settings})
      : connection =
            ClientTransportConnection.viaSocket(socket, settings: settings);

  Future<Response> makeRequest(Request request) {
    var path = request.uri.path;
    if (path.isEmpty) path = '/';

    var headers = [
      Header.ascii(':method', request.method),
      Header.ascii(':path', path),
      Header.ascii(':scheme', request.uri.scheme),
      Header.ascii(':authority', '${request.uri.host}'),
    ];

    return _handleStream(connection.makeRequest(headers, endStream: true));
  }

  Future close() {
    return connection.finish();
  }

  Future<Response> _handleStream(ClientTransportStream stream) {
    var completer = Completer<Response>();
    var isFirst = true;
    var controller = StreamController<List<int>>();
    var serverPushController = StreamController<ServerPush>(sync: true);
    stream.incomingMessages.listen((StreamMessage msg) {
      if (isFirst) {
        isFirst = false;
        var headerMap = _convertHeaders((msg as HeadersStreamMessage).headers);
        completer.complete(Response(
            headerMap, controller.stream, serverPushController.stream));
      } else {
        controller.add((msg as DataStreamMessage).bytes);
      }
    }, onDone: controller.close);
    _handlePeerPushes(stream.peerPushes).pipe(serverPushController);
    return completer.future;
  }

  Stream<ServerPush> _handlePeerPushes(
      Stream<TransportStreamPush> serverPushes) {
    var pushesController = StreamController<ServerPush>();
    serverPushes.listen((TransportStreamPush push) {
      var responseCompleter = Completer<Response>();
      var serverPush = ServerPush(
          _convertHeaders(push.requestHeaders), responseCompleter.future);

      pushesController.add(serverPush);

      var isFirst = true;
      var dataController = StreamController<List<int>>();
      push.stream.incomingMessages.listen((StreamMessage msg) {
        if (isFirst) {
          isFirst = false;
          var headerMap =
              _convertHeaders((msg as HeadersStreamMessage).headers);
          var response = Response(
              headerMap, dataController.stream, Stream.fromIterable([]));
          responseCompleter.complete(response);
        } else {
          dataController.add((msg as DataStreamMessage).bytes);
        }
      }, onDone: dataController.close);
    }, onDone: pushesController.close);
    return pushesController.stream;
  }

  Map<String, List<String>> _convertHeaders(List<Header> headers) {
    var headerMap = <String, List<String>>{};
    for (var header in headers) {
      headerMap
          .putIfAbsent(ascii.decode(header.name), () => [])
          .add(ascii.decode(header.value));
    }
    return headerMap;
  }
}

/// Tries to connect to [uri] via a secure socket connection and establishes a
/// http/2 connection.
///
/// If [allowServerPushes] is `true`, server pushes need to be handled by the
/// client. The maximum number of concurrent server pushes can be configured via
/// [maxConcurrentPushes] (default is `null` meaning no limit).
Future<ClientConnection> connect(Uri uri,
    {bool allowServerPushes = false, int maxConcurrentPushes}) async {
  const Http2AlpnProtocols = <String>['h2-14', 'h2-15', 'h2-16', 'h2-17', 'h2'];

  var useSSL = uri.scheme == 'https';
  var settings = ClientSettings(
      concurrentStreamLimit: maxConcurrentPushes,
      allowServerPushes: allowServerPushes);
  if (useSSL) {
    var socket = await SecureSocket.connect(uri.host, uri.port,
        supportedProtocols: Http2AlpnProtocols);
    if (!Http2AlpnProtocols.contains(socket.selectedProtocol)) {
      throw Exception('Server does not support HTTP/2.');
    }
    return ClientConnection(socket, settings: settings);
  } else {
    var socket = await Socket.connect(uri.host, uri.port);
    return ClientConnection(socket, settings: settings);
  }
}
