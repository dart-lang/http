// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'request_body_server_vm.dart'
    if (dart.library.html) 'request_body_server_web.dart';

class _Plus2Decoder extends Converter<List<int>, String> {
  @override
  String convert(List<int> input) =>
      const Utf8Decoder().convert(input.map((e) => e + 2).toList());
}

class _Plus2Encoder extends Converter<String, List<int>> {
  @override
  List<int> convert(String input) =>
      const Utf8Encoder().convert(input).map((e) => e - 2).toList();
}

/// An encoding, meant for testing, the just decrements input bytes by 2.
class _Plus2Encoding extends Encoding {
  @override
  Converter<List<int>, String> get decoder => _Plus2Decoder();

  @override
  Converter<String, List<int>> get encoder => _Plus2Encoder();

  @override
  String get name => 'plus2';
}

/// Tests that the [Client] correctly implements HTTP requests with bodies e.g.
/// 'POST'.
void testRequestBody(Client client) {
  group('request body', () {
    late final String host;
    late final StreamChannel<Object?> httpServerChannel;
    late final StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.next}';
    });
    tearDownAll(() => httpServerChannel.sink.add(null));

    test('client.post() with string body', () async {
      await client.post(Uri.http(host, ''), body: 'Hello World!');

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next;

      expect(serverReceivedContentType, ['text/plain; charset=utf-8']);
      expect(serverReceivedBody, 'Hello World!');
    });

    test('client.post() with string body and custom encoding', () async {
      await client.post(Uri.http(host, ''),
          body: 'Hello', encoding: _Plus2Encoding());

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next;

      expect(serverReceivedContentType, ['text/plain; charset=plus2']);
      expect(serverReceivedBody, 'Fcjjm');
    });

    test('client.post() with map body', () async {
      await client.post(Uri.http(host, ''), body: {'key': 'value'});

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next;

      expect(serverReceivedContentType,
          ['application/x-www-form-urlencoded; charset=utf-8']);
      expect(serverReceivedBody, 'key=value');
    });

    test('client.post() with map body and encoding', () async {
      await client.post(Uri.http(host, ''),
          body: {'key': 'value'}, encoding: _Plus2Encoding());

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next;

      expect(serverReceivedContentType,
          ['application/x-www-form-urlencoded; charset=plus2']);
      expect(serverReceivedBody, 'gau;r]hqa'); // key=value
    });

    test('client.post() with List<int>', () async {
      await client.post(Uri.http(host, ''), body: [1, 2, 3, 4, 5]);

      await httpServerQueue.next; // Content-Type.
      final serverReceivedBody = await httpServerQueue.next as String;

      // RFC 2616 7.2.1 says that:
      //   Any HTTP/1.1 message containing an entity-body SHOULD include a
      //   Content-Type header field defining the media type of that body.
      // But we didn't set one explicitly so don't verify what the server
      // received.
      expect(serverReceivedBody.codeUnits, [1, 2, 3, 4, 5]);
    });

    test('client.post() with List<int> and content-type', () async {
      await client.post(Uri.http(host, ''),
          headers: {'Content-Type': 'image/png'}, body: [1, 2, 3, 4, 5]);

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next as String;

      expect(serverReceivedContentType, ['image/png']);
      expect(serverReceivedBody.codeUnits, [1, 2, 3, 4, 5]);
    });

    test('client.post() with List<int> with encoding', () async {
      // Encoding should not affect binary payloads.
      await client.post(Uri.http(host, ''),
          body: [1, 2, 3, 4, 5], encoding: _Plus2Encoding());

      await httpServerQueue.next; // Content-Type.
      final serverReceivedBody = await httpServerQueue.next as String;

      // RFC 2616 7.2.1 says that:
      //   Any HTTP/1.1 message containing an entity-body SHOULD include a
      //   Content-Type header field defining the media type of that body.
      // But we didn't set one explicitly so don't verify what the server
      // received.
      expect(serverReceivedBody.codeUnits, [1, 2, 3, 4, 5]);
    });

    test('client.post() with List<int> with encoding and content-type',
        () async {
      // Encoding should not affect the payload but it should affect the
      // content-type.

      await client.post(Uri.http(host, ''),
          headers: {'Content-Type': 'image/png'},
          body: [1, 2, 3, 4, 5],
          encoding: _Plus2Encoding());

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next as String;

      expect(serverReceivedContentType, ['image/png; charset=plus2']);
      expect(serverReceivedBody.codeUnits, [1, 2, 3, 4, 5]);
    });
  });
}
