// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http2/src/http2_client.dart';
import 'package:http2/transport.dart';
import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:test/test.dart';

class Http2ProxyServer {
  final SecureServerSocket _socket;
  final List<ServerTransportConnection> _connections = [];
  final IOClient _httpClient = IOClient();

  Http2ProxyServer._(this._socket) {
    _socket.listen((socket) {
      final connection = ServerTransportConnection.viaSocket(socket);
      _connections.add(connection);
      connection.incomingStreams.listen(_handleStream);
    });
  }

  static Future<Http2ProxyServer> start() async {
    final context =
        SecurityContext()
          ..useCertificateChain('test/certificates/server_chain.pem')
          ..usePrivateKey(
            'test/certificates/server_key.pem',
            password: 'dartdart',
          )
          ..setAlpnProtocols(['h2'], true);
    final socket = await SecureServerSocket.bind('localhost', 0, context);
    return Http2ProxyServer._(socket);
  }

  int get port => _socket.port;

  Future<void> _handleStream(ServerTransportStream stream) async {
    try {
      final messages = StreamIterator(stream.incomingMessages);
      if (!await messages.moveNext()) return;

      final headersMsg = messages.current as HeadersStreamMessage;
      String? method;
      String? path;
      int? targetPort;
      final headers = <String, String>{};

      for (final header in headersMsg.headers) {
        final name = ascii.decode(header.name);
        final value = ascii.decode(header.value);
        if (name == ':method') {
          method = value;
        } else if (name == ':path') {
          path = value;
        } else if (name == 'x-target-port') {
          targetPort = int.parse(value);
        } else if (!name.startsWith(':')) {
          headers[name] = value;
        }
      }

      if (method == null || path == null || targetPort == null) {
        stream.outgoingMessages.add(
          HeadersStreamMessage([Header.ascii(':status', '400')]),
        );
        await stream.outgoingMessages.close();
        return;
      }

      // Collect body
      final bodyBytes = <int>[];
      while (await messages.moveNext()) {
        final msg = messages.current;
        if (msg is DataStreamMessage) {
          bodyBytes.addAll(msg.bytes);
        }
      }

      // Forward to HTTP/1.1 server
      final targetUri = Uri.parse('http://localhost:$targetPort$path');
      final httpRequest = http.Request(method, targetUri);
      headers.forEach((k, v) {
        httpRequest.headers[k] = v;
      });
      httpRequest.bodyBytes = bodyBytes;

      final httpResponse = await _httpClient.send(httpRequest);

      // Send response headers
      final responseHeaders = <Header>[
        Header.ascii(':status', httpResponse.statusCode.toString()),
      ];
      httpResponse.headers.forEach((k, v) {
        responseHeaders.add(Header.ascii(k.toLowerCase(), v));
      });
      stream.outgoingMessages.add(HeadersStreamMessage(responseHeaders));

      // Send response body
      await for (final chunk in httpResponse.stream) {
        stream.outgoingMessages.add(DataStreamMessage(chunk));
      }
      await stream.outgoingMessages.close();
    } catch (e) {
      print('Proxy error: $e');
      stream.terminate();
    }
  }

  Future<void> close() async {
    await _socket.close();
    for (final conn in _connections) {
      await conn.terminate();
    }
    _httpClient.close();
  }
}

class ProxyRequest extends http.BaseRequest implements http.Abortable {
  // `url` is not redeclared here - BaseRequest's own constructor stores it.
  ProxyRequest(this._original, Uri url) : super(_original.method, url);

  final http.BaseRequest _original;

  @override
  Future<void>? get abortTrigger =>
      _original is http.Abortable ? _original.abortTrigger : null;

  @override
  Map<String, String> get headers => _original.headers;

  @override
  int? get contentLength => _original.contentLength;
  @override
  set contentLength(int? value) => _original.contentLength = value;

  @override
  bool get followRedirects => _original.followRedirects;
  @override
  set followRedirects(bool value) => _original.followRedirects = value;

  @override
  int get maxRedirects => _original.maxRedirects;
  @override
  set maxRedirects(int value) => _original.maxRedirects = value;

  @override
  bool get persistentConnection => _original.persistentConnection;
  @override
  set persistentConnection(bool value) =>
      _original.persistentConnection = value;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return _original.finalize();
  }
}

class ConformanceProxyClient extends http.BaseClient {
  final Http2Client _inner;
  final int _proxyPort;

  ConformanceProxyClient(this._inner, this._proxyPort);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final targetPort = request.url.port;
    final proxyUrl = request.url.replace(
      scheme: 'https',
      host: 'localhost',
      port: _proxyPort,
    );

    request.headers['x-target-port'] = targetPort.toString();
    final proxyRequest = ProxyRequest(request, proxyUrl);

    try {
      final response = await _inner.send(proxyRequest);
      return http.StreamedResponse(
        response.stream,
        response.statusCode,
        contentLength: response.contentLength,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
        request: request,
      );
    } on http.ClientException catch (e) {
      if (e is http.RequestAbortedException) {
        throw http.RequestAbortedException(request.url);
      }
      throw http.ClientException(e.message, request.url);
    }
  }

  @override
  void close() {
    _inner.close();
  }
}

/// [Http2Client] only supports HTTP/2 over TLS (HTTPS). However, the standard
/// servers started by http_client_conformance_tests only support unencrypted
/// HTTP/1.1.
/// To bridge this protocol gap, we run a local HTTP/2 proxy server
/// ([Http2ProxyServer]) in-process. [ConformanceProxyClient] wraps
/// [Http2Client] and rewrites the destination URI of all outgoing requests to
/// point to the local proxy server, attaching a custom `x-target-port` header
/// to specify the target HTTP/1.1 server port. The proxy server then forwards
/// the request over HTTP/1.1 and returns the response to [Http2Client] over
/// HTTP/2.
void main() {
  late final Http2ProxyServer proxy;

  setUpAll(() async {
    proxy = await Http2ProxyServer.start();
  });

  tearDownAll(() async {
    await proxy.close();
  });

  ConformanceProxyClient clientFactory() => ConformanceProxyClient(
    Http2Client(onBadCertificate: (_) => true),
    proxy.port,
  );

  testRequestBody(clientFactory);

  // TODO: Implement request body streaming support in Http2Client.
  // Currently Http2Client reads the entire request body into memory before
  // sending.
  testRequestBodyStreamed(clientFactory, canStreamRequestBody: false);

  testResponseBody(clientFactory);
  // TODO: Re-enable once request abort support is implemented in Http2Client.
  // testResponseBodyStreamed(clientFactory);
  testRequestHeaders(clientFactory);
  testRequestMethods(clientFactory, preservesMethodCase: false);

  testResponseHeaders(
    clientFactory,
    // HTTP/2 explicitly forbids folded headers (RFC 7540 Section 8.1.2.6).
    supportsFoldedHeaders: false,
    // HTTP/2 does not allow NUL characters inside header names or values.
    correctlyHandlesNullHeaderValues: false,
  );

  testResponseStatusLine(clientFactory);

  // TODO: Implement redirect-following support in Http2Client.
  // testRedirect(clientFactory);

  testServerErrors(clientFactory);
  testCompressedResponseBody(clientFactory);
  testMultipleClients(clientFactory);
  testMultipartRequests(clientFactory, supportsMultipartRequest: true);
  testClose(clientFactory);

  // TODO: Support running client conformance tests in isolates.
  // Currently we set `canWorkInIsolates` to false because the proxy server uses
  // `SecureServerSocket`, which cannot be sent across isolates.
  testIsolate(clientFactory, canWorkInIsolates: false);

  testRequestCookies(clientFactory, canSendCookieHeaders: true);
  testResponseCookies(clientFactory, canReceiveSetCookieHeaders: true);

  // TODO: Implement request abort support in Http2Client.
  // testAbort(
  //   clientFactory,
  //   supportsAbort: true,
  //   canStreamRequestBody: false,
  //   canStreamResponseBody: true,
  // );
}
