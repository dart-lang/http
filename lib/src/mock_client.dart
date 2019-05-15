// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'base_client.dart';
import 'base_request.dart';
import 'byte_stream.dart';
import 'request.dart';
import 'response.dart';
import 'streamed_response.dart';

// TODO(nweiz): once Dart has some sort of Rack- or WSGI-like standard for
// server APIs, MockClient should conform to it.

/// A mock HTTP client designed for use when testing code that uses
/// [BaseClient]. This client allows you to define a handler callback for all
/// requests that are made through it so that you can mock a server without
/// having to send real HTTP requests.
class MockClient extends BaseClient {
  /// The handler for receiving [StreamedRequest]s and sending
  /// [StreamedResponse]s.
  final MockClientStreamHandler _handler;

  MockClient._(this._handler);

  /// Creates a [MockClient] with a handler that receives [Request]s and sends
  /// [Response]s.
  MockClient(MockClientHandler fn)
      : this._((baseRequest, bodyStream) {
          return bodyStream.toBytes().then((bodyBytes) {
            var request = Request(baseRequest.method, baseRequest.url)
              ..persistentConnection = baseRequest.persistentConnection
              ..followRedirects = baseRequest.followRedirects
              ..maxRedirects = baseRequest.maxRedirects
              ..headers.addAll(baseRequest.headers)
              ..bodyBytes = bodyBytes
              ..finalize();

            return fn(request);
          }).then((response) {
            return StreamedResponse(
                ByteStream.fromBytes(response.bodyBytes), response.statusCode,
                contentLength: response.contentLength,
                request: baseRequest,
                headers: response.headers,
                isRedirect: response.isRedirect,
                persistentConnection: response.persistentConnection,
                reasonPhrase: response.reasonPhrase);
          });
        });

  /// Creates a [MockClient] with a handler that receives [StreamedRequest]s and
  /// sends [StreamedResponse]s.
  MockClient.streaming(MockClientStreamHandler fn)
      : this._((request, bodyStream) {
          return fn(request, bodyStream).then((response) {
            return StreamedResponse(response.stream, response.statusCode,
                contentLength: response.contentLength,
                request: request,
                headers: response.headers,
                isRedirect: response.isRedirect,
                persistentConnection: response.persistentConnection,
                reasonPhrase: response.reasonPhrase);
          });
        });

  /// Sends a request.
  Future<StreamedResponse> send(BaseRequest request) async {
    var bodyStream = request.finalize();
    return await _handler(request, bodyStream);
  }
}

/// A handler function that receives [StreamedRequest]s and sends
/// [StreamedResponse]s. Note that [request] will be finalized.
typedef MockClientStreamHandler = Future<StreamedResponse> Function(
    BaseRequest request, ByteStream bodyStream);

/// A handler function that receives [Request]s and sends [Response]s. Note that
/// [request] will be finalized.
typedef MockClientHandler = Future<Response> Function(Request request);
