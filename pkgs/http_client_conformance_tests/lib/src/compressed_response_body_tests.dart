// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'compressed_response_body_server_vm.dart'
    if (dart.library.html) 'compressed_response_body_server_web.dart';

/// Tests that the [Client] correctly implements HTTP responses with compressed
/// bodies.
///
/// If the response is encoded using a recognized 'Content-Encoding' then the
/// [Client] must decode it. Otherwise it must return the content unchanged.
///
/// The 'Content-Encoding' and 'Content-Length' headers may be absent for
/// responses with a 'Content-Encoding' and, if present, their values are
/// undefined.
///
/// The value of `StreamedResponse.contentLength` is not defined for responses
/// with a 'Content-Encoding' header.
void testCompressedResponseBody(Client client) async {
  group('response body', () {
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;
    const message = 'Hello World!';

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('gzip: small response with content length', () async {
      // Test a supported content encoding.
      final response = await client.get(Uri.http(host, '/gzip'));
      final requestHeaders = await httpServerQueue.next as Map;

      expect((requestHeaders['accept-encoding'] as List).join(', '),
          contains('gzip'));
      expect(response.body, message);
      expect(response.bodyBytes, message.codeUnits);
      expect(response.contentLength, message.length);
      expect(response.headers['content-type'], 'text/plain');
      expect(response.isRedirect, isFalse);
      expect(response.reasonPhrase, 'OK');
      expect(response.request!.method, 'GET');
      expect(response.statusCode, 200);
    });

    test('gzip: small response streamed with content length', () async {
      // Test a supported content encoding.
      final request = Request('GET', Uri.http(host, '/gzip', {'length': ''}));
      final response = await client.send(request);
      final requestHeaders = await httpServerQueue.next as Map;

      expect((requestHeaders['accept-encoding'] as List).join(', '),
          contains('gzip'));
      expect(await response.stream.bytesToString(), message);
      expect(response.headers['content-type'], 'text/plain');
      expect(response.isRedirect, isFalse);
      expect(response.reasonPhrase, 'OK');
      expect(response.request!.method, 'GET');
      expect(response.statusCode, 200);
    });

    test('upper: small response streamed with content length', () async {
      // Test an unsupported content encoding.
      final request = Request('GET', Uri.http(host, '/upper', {'length': ''}));
      final response = await client.send(request);
      await httpServerQueue.next;

      expect(await response.stream.bytesToString(), message.toUpperCase());
      expect(response.headers['content-type'], 'text/plain');
      expect(response.isRedirect, isFalse);
      expect(response.reasonPhrase, 'OK');
      expect(response.request!.method, 'GET');
      expect(response.statusCode, 200);
    });
  });
}
