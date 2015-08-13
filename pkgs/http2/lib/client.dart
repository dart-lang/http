// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library http2.client;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'transport.dart';

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

  ClientConnection(Socket socket, {bool allowServerPushes: false})
      : connection = new ClientTransportConnection.viaSocket(
          socket, allowServerPushes: allowServerPushes);

  Future<Response> makeRequest(Request request) {
    var path = request.uri.path;
    if (path.isEmpty) path = '/';

    var headers = [
      new Header.ascii(':method', request.method),
      new Header.ascii(':path', path),
      new Header.ascii(':scheme', request.uri.scheme),
      new Header.ascii(':authority', '${request.uri.host}'),
    ];

    return _handleStream(connection.makeRequest(headers, endStream: true));
  }

  Future close() {
    return connection.finish();
  }

  Future<Response> _handleStream(ClientTransportStream stream) {
    var completer = new Completer();
    bool isFirst = true;
    var controller = new StreamController();
    var serverPushController = new StreamController(sync: true);
    stream.incomingMessages.listen((StreamMessage msg) {
      if (isFirst) {
        isFirst = false;
        var headerMap = _convertHeaders((msg as HeadersStreamMessage).headers);
        completer.complete(new Response(
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
    var pushesController = new StreamController();
    serverPushes.listen((TransportStreamPush push) {
      var responseCompleter = new Completer();
      var serverPush = new ServerPush(
          _convertHeaders(push.requestHeaders), responseCompleter.future);

      pushesController.add(serverPush);

      bool isFirst = true;
      var dataController = new StreamController();
      push.stream.incomingMessages.listen((StreamMessage msg) {
        if (isFirst) {
          isFirst = false;
          var headerMap =
              _convertHeaders((msg as HeadersStreamMessage).headers);
          var response = new Response(
              headerMap, dataController.stream, new Stream.fromIterable([]));
          responseCompleter.complete(response);
        } else {
          dataController.add((msg as DataStreamMessage).bytes);
        }
      }, onDone: dataController.close);
    }, onDone: pushesController.close);
    return pushesController.stream;
  }

  Map<String, List<String>> _convertHeaders(List<Header> headers) {
    var headerMap = {};
    for (var header in headers) {
      headerMap.putIfAbsent(ASCII.decode(header.name), () => [])
      .add(ASCII.decode(header.value));
    }
    return headerMap;
  }

}

Future<ClientConnection> connect(
    Uri uri, {bool allowServerPushes: false}) async {
  const List<String> Http2AlpnProtocols =
      const <String>['h2-14', 'h2-15', 'h2-16', 'h2-17', 'h2'];

  bool useSSL = uri.scheme == 'https';
  if (useSSL) {
    SecureSocket socket = await SecureSocket.connect(
        uri.host, uri.port, supportedProtocols: Http2AlpnProtocols);
    if (!Http2AlpnProtocols.contains(socket.selectedProtocol)) {
      throw  new Exception('Server does not support HTTP/2.');
    }
    return new ClientConnection(socket, allowServerPushes: allowServerPushes);
  } else {
    Socket socket = await Socket.connect(uri.host, uri.port);
    return new ClientConnection(socket, allowServerPushes: allowServerPushes);
  }
}
