// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:test/test.dart';

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
///
/// If [canStreamRequestBody] is `false` then tests that assume that the
/// [Client] supports sending HTTP requests with unbounded body sizes will be
/// skipped.
void testRequestBody(Client client, {bool canStreamRequestBody = true}) {
  group('request body', () {
    test('client.post() with string body', () async {
      late List<String>? serverReceivedContentType;
      late String serverReceivedBody;

      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          serverReceivedContentType =
              request.headers[HttpHeaders.contentTypeHeader];
          serverReceivedBody = await const Utf8Decoder()
              .bind(request)
              .fold('', (p, e) => '$p$e');
          unawaited(request.response.close());
        });
      await client.post(Uri.parse('http://localhost:${server.port}'),
          body: 'Hello World!');

      expect(serverReceivedContentType, ['text/plain; charset=utf-8']);
      expect(serverReceivedBody, 'Hello World!');
      await server.close();
    });

    test('client.post() with string body and custom encoding', () async {
      late List<String>? serverReceivedContentType;
      late String serverReceivedBody;

      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          serverReceivedContentType =
              request.headers[HttpHeaders.contentTypeHeader];
          serverReceivedBody = await const Utf8Decoder()
              .bind(request)
              .fold('', (p, e) => '$p$e');
          unawaited(request.response.close());
        });
      await client.post(Uri.parse('http://localhost:${server.port}'),
          body: 'Hello', encoding: _Plus2Encoding());

      expect(serverReceivedContentType, ['text/plain; charset=plus2']);
      expect(serverReceivedBody, 'Fcjjm');
      await server.close();
    });

    test('client.post() with map body', () async {
      late List<String>? serverReceivedContentType;
      late String serverReceivedBody;

      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          serverReceivedContentType =
              request.headers[HttpHeaders.contentTypeHeader];
          serverReceivedBody = await const Utf8Decoder()
              .bind(request)
              .fold('', (p, e) => '$p$e');
          unawaited(request.response.close());
        });
      await client.post(Uri.parse('http://localhost:${server.port}'),
          body: {'key': 'value'});
      expect(serverReceivedContentType,
          ['application/x-www-form-urlencoded; charset=utf-8']);
      expect(serverReceivedBody, 'key=value');
      await server.close();
    });

    test('client.post() with map body and encoding', () async {
      late List<String>? serverReceivedContentType;
      late String serverReceivedBody;

      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          serverReceivedContentType =
              request.headers[HttpHeaders.contentTypeHeader];
          serverReceivedBody = await const Utf8Decoder()
              .bind(request)
              .fold('', (p, e) => '$p$e');
          unawaited(request.response.close());
        });
      await client.post(Uri.parse('http://localhost:${server.port}'),
          body: {'key': 'value'}, encoding: _Plus2Encoding());
      expect(serverReceivedContentType,
          ['application/x-www-form-urlencoded; charset=plus2']);
      expect(serverReceivedBody, 'gau;r]hqa'); // key=value
      await server.close();
    });

    test('client.post() with List<int>', () async {
      late String serverReceivedBody;

      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          serverReceivedBody = await const Utf8Decoder()
              .bind(request)
              .fold('', (p, e) => '$p$e');
          unawaited(request.response.close());
        });
      await client.post(Uri.parse('http://localhost:${server.port}'),
          body: [1, 2, 3, 4, 5]);

      // RFC 2616 7.2.1 says that:
      //   Any HTTP/1.1 message containing an entity-body SHOULD include a
      //   Content-Type header field defining the media type of that body.
      // But we didn't set one explicitly so don't verify what the server
      // received.
      expect(serverReceivedBody.codeUnits, [1, 2, 3, 4, 5]);
      await server.close();
    });

    test('client.post() with List<int> and content-type', () async {
      late List<String>? serverReceivedContentType;
      late String serverReceivedBody;

      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          serverReceivedContentType =
              request.headers[HttpHeaders.contentTypeHeader];
          serverReceivedBody = await const Utf8Decoder()
              .bind(request)
              .fold('', (p, e) => '$p$e');
          unawaited(request.response.close());
        });
      await client.post(Uri.parse('http://localhost:${server.port}'),
          headers: {HttpHeaders.contentTypeHeader: 'image/png'},
          body: [1, 2, 3, 4, 5]);

      expect(serverReceivedContentType, ['image/png']);
      expect(serverReceivedBody.codeUnits, [1, 2, 3, 4, 5]);
      await server.close();
    });

    test('client.post() with List<int> with encoding', () async {
      // Encoding should not affect binary payloads.
      late String serverReceivedBody;

      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          serverReceivedBody = await const Utf8Decoder()
              .bind(request)
              .fold('', (p, e) => '$p$e');
          unawaited(request.response.close());
        });
      await client.post(Uri.parse('http://localhost:${server.port}'),
          body: [1, 2, 3, 4, 5], encoding: _Plus2Encoding());

      // RFC 2616 7.2.1 says that:
      //   Any HTTP/1.1 message containing an entity-body SHOULD include a
      //   Content-Type header field defining the media type of that body.
      // But we didn't set one explicitly so don't verify what the server
      // received.
      expect(serverReceivedBody.codeUnits, [1, 2, 3, 4, 5]);
      await server.close();
    });

    test('client.post() with List<int> with encoding and content-type',
        () async {
      // Encoding should not affect the payload but it should affect the
      // content-type.
      late List<String>? serverReceivedContentType;
      late String serverReceivedBody;

      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          serverReceivedContentType =
              request.headers[HttpHeaders.contentTypeHeader];
          serverReceivedBody = await const Utf8Decoder()
              .bind(request)
              .fold('', (p, e) => '$p$e');
          unawaited(request.response.close());
        });
      await client.post(Uri.parse('http://localhost:${server.port}'),
          headers: {HttpHeaders.contentTypeHeader: 'image/png'},
          body: [1, 2, 3, 4, 5],
          encoding: _Plus2Encoding());

      expect(serverReceivedContentType, ['image/png; charset=plus2']);
      expect(serverReceivedBody.codeUnits, [1, 2, 3, 4, 5]);
      await server.close();
    });

    test('client.send() with StreamedRequest', () async {
      // The client continuously streams data to the server until
      // instructed to stop (by setting `clientWriting` to `false`).
      // The server sets `serverWriting` to `false` after it has
      // already received some data.
      //
      // This ensures that the client supports streamed data sends.
      var lastReceived = 0;
      var clientWriting = true;
      final server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await const LineSplitter()
              .bind(const Utf8Decoder().bind(request))
              .forEach((s) {
            lastReceived = int.parse(s.trim());
            if (lastReceived < 1000) {
              expect(clientWriting, true);
            } else {
              clientWriting = false;
            }
          });
          unawaited(request.response.close());
        });
      Stream<String> count() async* {
        var i = 0;
        while (clientWriting) {
          yield '${i++}\n';
          // Let the event loop run.
          await Future<void>.delayed(const Duration());
        }
      }

      final request =
          StreamedRequest('POST', Uri.parse('http://localhost:${server.port}'));
      const Utf8Encoder()
          .bind(count())
          .listen(request.sink.add, onDone: request.sink.close);
      await client.send(request);

      expect(lastReceived, greaterThanOrEqualTo(1000));
      await server.close();
    }, skip: canStreamRequestBody ? false : 'does not stream request bodies');
  });
}
