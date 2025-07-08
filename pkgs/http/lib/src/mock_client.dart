// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'abortable.dart';
import 'base_client.dart';
import 'base_request.dart';
import 'byte_stream.dart';
import 'request.dart';
import 'response.dart';
import 'streamed_request.dart';
import 'streamed_response.dart';

final _pngImageData = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDw'
  'AEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

// TODO(nweiz): once Dart has some sort of Rack- or WSGI-like standard for
// server APIs, MockClient should conform to it.

/// A mock HTTP client designed for use when testing code that uses
/// [BaseClient].
///
/// This client allows you to define a handler callback for all requests that
/// are made through it so that you can mock a server without having to send
/// real HTTP requests.
///
/// This client does not support aborting requests directly - it is the
/// handler's responsibility to throw [RequestAbortedException] as and when
/// necessary.
class MockClient extends BaseClient {
  /// The handler for receiving [StreamedRequest]s and sending
  /// [StreamedResponse]s.
  final MockClientStreamHandler _handler;

  MockClient._(this._handler);

  /// Creates a [MockClient] with a handler that receives [Request]s and sends
  /// [Response]s.
  MockClient(MockClientHandler fn)
      : this._((baseRequest, bodyStream) async {
          final bodyBytes = await bodyStream.toBytes();
          var request = Request(baseRequest.method, baseRequest.url)
            ..persistentConnection = baseRequest.persistentConnection
            ..followRedirects = baseRequest.followRedirects
            ..maxRedirects = baseRequest.maxRedirects
            ..headers.addAll(baseRequest.headers)
            ..bodyBytes = bodyBytes
            ..finalize();

          final response = await fn(request);
          return StreamedResponse(
              ByteStream.fromBytes(response.bodyBytes), response.statusCode,
              contentLength: response.contentLength,
              request: response.request,
              headers: response.headers,
              isRedirect: response.isRedirect,
              persistentConnection: response.persistentConnection,
              reasonPhrase: response.reasonPhrase);
        });

  /// Creates a [MockClient] with a handler that receives [StreamedRequest]s and
  /// sends [StreamedResponse]s.
  MockClient.streaming(MockClientStreamHandler fn)
      : this._((request, bodyStream) async {
          final response = await fn(request, bodyStream);
          return StreamedResponse(response.stream, response.statusCode,
              contentLength: response.contentLength,
              request: response.request,
              headers: response.headers,
              isRedirect: response.isRedirect,
              persistentConnection: response.persistentConnection,
              reasonPhrase: response.reasonPhrase);
        });

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    var bodyStream = request.finalize();
    return await _handler(request, bodyStream);
  }

  /// Return a response containing a PNG image.
  static Response pngResponse({BaseRequest? request}) {
    final headers = {
      'content-type': 'image/png',
      'content-length': '${_pngImageData.length}'
    };

    return Response.bytes(_pngImageData, 200,
        request: request, headers: headers, reasonPhrase: 'OK');
  }
}

/// A handler function that receives [StreamedRequest]s and sends
/// [StreamedResponse]s.
///
/// Note that [request] will be finalized.
typedef MockClientStreamHandler = Future<StreamedResponse> Function(
    BaseRequest request, ByteStream bodyStream);

/// A handler function that receives [Request]s and sends [Response]s.
///
/// Note that [request] will be finalized.
typedef MockClientHandler = Future<Response> Function(Request request);
