// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import 'package:test/test.dart';

import '../utils.dart';

class TestClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }
}

class TestClient2 extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }
}

void main() {
  late Uri serverUrl;
  setUpAll(() async {
    serverUrl = await startServer();
  });

  test('aborting without reading the response frees the underlying connection',
      () async {
    // Pool of exactly one: a held connection makes the next request hang.
    final ioClient = HttpClient()..maxConnectionsPerHost = 1;
    final client = http_io.IOClient(ioClient);
    addTearDown(client.close);

    final abortTrigger = Completer<void>();
    final request = http.AbortableRequest('GET', serverUrl,
        abortTrigger: abortTrigger.future);

    await client.send(request);

    // Abort after we have the response but before reading it.
    abortTrigger.complete();

    // Can only succeed if the aborted request's connection was released.
    final request2 = http.Request('GET', serverUrl);
    final response2 =
        await client.send(request2).timeout(const Duration(seconds: 5));
    final body2 = await http.Response.fromStream(response2);

    expect(response2.statusCode, 200);
    expect(body2.body, isNotEmpty);
  });

  test('aborting after the response is fully read raises no async error',
      () async {
    final errors = <Object>[];

    await runZonedGuarded(() async {
      final client = http_io.IOClient();
      addTearDown(client.close);

      final abortTrigger = Completer<void>();
      final request = http.AbortableRequest('GET', serverUrl,
          abortTrigger: abortTrigger.future);

      final response = await client.send(request);
      final body = await http.Response.fromStream(response);
      expect(body.statusCode, 200);

      abortTrigger.complete();
      await Future<void>.delayed(Duration.zero); // let the handlers run
    }, (e, _) => errors.add(e));

    expect(errors, isEmpty);
  });

  test('aborting while streaming frees the connection', () async {
    final ioClient = HttpClient()..maxConnectionsPerHost = 1; // pool of 1
    final client = http_io.IOClient(ioClient);
    addTearDown(client.close);

    final abortTrigger = Completer<void>();
    final request = http.AbortableRequest('GET', serverUrl,
        abortTrigger: abortTrigger.future);

    final response = await client.send(request);

    // Start streaming, then abort before the body's I/O events are delivered.
    response.stream.listen((_) {}, onError: (_) {});
    abortTrigger.complete();

    // Only returns if the aborted connection was released back to the pool.
    final response2 = await client
        .send(http.Request('GET', serverUrl))
        .timeout(const Duration(seconds: 5));
    final body2 = await http.Response.fromStream(response2);
    expect(response2.statusCode, 200);
    expect(body2.body, isNotEmpty);
  });

  test('#send a StreamedRequest', () async {
    var client = http.Client();
    var request = http.StreamedRequest('POST', serverUrl)
      ..headers[HttpHeaders.contentTypeHeader] =
          'application/json; charset=utf-8'
      ..headers[HttpHeaders.userAgentHeader] = 'Dart';

    var responseFuture = client.send(request);
    request.sink.add('{"hello": "world"}'.codeUnits);
    unawaited(request.sink.close());

    var response = await responseFuture;

    expect(response.request, equals(request));
    expect(response.statusCode, equals(200));
    expect(response.headers['single'], equals('value'));
    // dart:io internally normalizes outgoing headers so that they never
    // have multiple headers with the same name, so there's no way to test
    // whether we handle that case correctly.

    var bytesString = await response.stream.bytesToString();
    client.close();
    expect(
        bytesString,
        parse(equals({
          'method': 'POST',
          'path': '/',
          'headers': {
            'content-type': ['application/json; charset=utf-8'],
            'accept-encoding': ['gzip'],
            'user-agent': ['Dart'],
            'transfer-encoding': ['chunked']
          },
          'body': '{"hello": "world"}'
        })));
  });

  test('#send a StreamedRequest with a custom client', () async {
    var ioClient = HttpClient();
    var client = http_io.IOClient(ioClient);
    var request = http.StreamedRequest('POST', serverUrl)
      ..headers[HttpHeaders.contentTypeHeader] =
          'application/json; charset=utf-8'
      ..headers[HttpHeaders.userAgentHeader] = 'Dart';

    var responseFuture = client.send(request);
    request.sink.add('{"hello": "world"}'.codeUnits);
    unawaited(request.sink.close());

    var response = await responseFuture;

    expect(response.request, equals(request));
    expect(response.statusCode, equals(200));
    expect(response.headers['single'], equals('value'));
    // dart:io internally normalizes outgoing headers so that they never
    // have multiple headers with the same name, so there's no way to test
    // whether we handle that case correctly.

    var bytesString = await response.stream.bytesToString();
    client.close();
    expect(
        bytesString,
        parse(equals({
          'method': 'POST',
          'path': '/',
          'headers': {
            'content-type': ['application/json; charset=utf-8'],
            'accept-encoding': ['gzip'],
            'user-agent': ['Dart'],
            'transfer-encoding': ['chunked']
          },
          'body': '{"hello": "world"}'
        })));
  });

  test('#send with an invalid URL', () {
    var client = http.Client();
    var url = Uri.http('http.invalid', '');
    var request = http.StreamedRequest('POST', url);
    request.headers[HttpHeaders.contentTypeHeader] =
        'application/json; charset=utf-8';

    expect(
        client.send(request),
        throwsA(allOf(
            isA<http.ClientException>().having((e) => e.uri, 'uri', url),
            isA<SocketException>().having(
                (e) => e.toString(),
                'SocketException.toString',
                matches('ClientException with SocketException.*,'
                    ' uri=http://http.invalid')))));

    request.sink.add('{"hello": "world"}'.codeUnits);
    request.sink.close();
  });

  test('sends a MultipartRequest with correct content-type header', () async {
    var client = http.Client();
    var request = http.MultipartRequest('POST', serverUrl);

    var response = await client.send(request);

    var bytesString = await response.stream.bytesToString();
    client.close();

    var headers = (jsonDecode(bytesString) as Map<String, dynamic>)['headers']
        as Map<String, dynamic>;
    var contentType = (headers['content-type'] as List).single;
    expect(contentType, startsWith('multipart/form-data; boundary='));
  });

  test('detachSocket returns a socket from an IOStreamedResponse', () async {
    var ioClient = HttpClient();
    var client = http_io.IOClient(ioClient);
    var request = http.Request('GET', serverUrl);

    var response = await client.send(request);
    var socket = await response.detachSocket();

    expect(socket, isNotNull);
  });

  test('runWithClient', () {
    final client = http.runWithClient(http.Client.new, TestClient.new);
    expect(client, isA<TestClient>());
  });

  test('runWithClient Client() return', () {
    final client = http.runWithClient(http.Client.new, http.Client.new);
    expect(client, isA<http_io.IOClient>());
  });

  test('runWithClient nested', () {
    late final http.Client client;
    late final http.Client nestedClient;
    http.runWithClient(() {
      http.runWithClient(() => nestedClient = http.Client(), TestClient2.new);
      client = http.Client();
    }, TestClient.new);
    expect(client, isA<TestClient>());
    expect(nestedClient, isA<TestClient2>());
  });

  test('runWithClient recursion', () {
    // Verify that calling the http.Client() factory inside nested Zones does
    // not provoke an infinite recursion.
    http.runWithClient(() {
      http.runWithClient(http.Client.new, http.Client.new);
    }, http.Client.new);
  });

  test('preserves header case', () async {
    // Avoid `HttpServer` header normalization with a direct socket server.
    final server = await ServerSocket.bind('localhost', 0);
    final url = Uri.http('localhost:${server.port}', '');

    final client = http.Client();
    final request = http.Request('POST', url)
      ..headers['X-Custom-Header'] = 'value';

    final responseFuture = client.send(request);

    final socket = await server.first;
    final bytes = BytesBuilder();
    const needle = [13, 10, 13, 10];
    var needleIndex = 0;

    collectHeader:
    await for (var data in socket) {
      bytes.add(data);
      for (final byte in data) {
        if (byte == needle[needleIndex]) {
          if (++needleIndex == 4) break collectHeader;
        } else {
          needleIndex = (byte == 13) ? 1 : 0;
        }
      }
    }

    expect(utf8.decode(bytes.toBytes()), contains('X-Custom-Header: value'));

    socket.write('HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n');
    await socket.flush();
    await socket.close();
    await server.close();

    final response = await responseFuture;
    expect(response.statusCode, equals(200));
    client.close();
  });
}
