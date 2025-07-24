// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'request_body_server_vm.dart'
    if (dart.library.js_interop) 'request_body_server_web.dart';

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
    late String host;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUp(() async {
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.nextAsInt}';
    });
    tearDown(() => httpServerChannel.sink.add(null));

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

      expect(serverReceivedContentType, ['application/x-www-form-urlencoded']);
      expect(serverReceivedBody, 'key=value');
    });

    test('client.post() with map body and encoding', () async {
      await client.post(Uri.http(host, ''),
          body: {'key': 'value'}, encoding: _Plus2Encoding());

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next;

      expect(serverReceivedContentType, ['application/x-www-form-urlencoded']);
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

      expect(serverReceivedContentType, ['image/png']);
      expect(serverReceivedBody.codeUnits, [1, 2, 3, 4, 5]);
    });

    test('client.send() with stream containing empty lists', () async {
      final request = StreamedRequest('POST', Uri.http(host, ''));
      request.headers['Content-Type'] = 'image/png';
      request.sink.add([]);
      request.sink.add([]);
      request.sink.add([1]);
      request.sink.add([2]);
      request.sink.add([]);
      request.sink.add([3, 4]);
      request.sink.add([]);
      request.sink.add([5]);
      // ignore: unawaited_futures
      request.sink.close();
      await client.send(request);

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next as String;

      expect(serverReceivedContentType, ['image/png']);
      expect(serverReceivedBody.codeUnits, [1, 2, 3, 4, 5]);
    });

    test('client.send() with slow stream', () async {
      Stream<List<int>> stream() async* {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        yield [1];
        await Future<void>.delayed(const Duration(milliseconds: 100));
        yield [2];
        await Future<void>.delayed(const Duration(milliseconds: 100));
        yield [3];
        await Future<void>.delayed(const Duration(milliseconds: 100));
        yield [4];
        await Future<void>.delayed(const Duration(milliseconds: 100));
        yield [5];
        await Future<void>.delayed(const Duration(milliseconds: 100));
        yield [6, 7, 8];
        await Future<void>.delayed(const Duration(milliseconds: 100));
        yield [9, 10];
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      final request = StreamedRequest('POST', Uri.http(host, ''));
      request.headers['Content-Type'] = 'image/png';

      stream().listen(request.sink.add,
          onError: request.sink.addError, onDone: request.sink.close);
      await client.send(request);

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next as String;

      expect(serverReceivedContentType, ['image/png']);
      expect(serverReceivedBody.codeUnits, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    test('client.send() with stream that raises', () async {
      Stream<List<int>> stream() async* {
        yield [0];
        yield [1];
        throw ArgumentError('this is a test');
      }

      final request = StreamedRequest('POST', Uri.http(host, ''));
      request.headers['Content-Type'] = 'image/png';

      stream().listen(request.sink.add,
          onError: request.sink.addError, onDone: request.sink.close);

      await expectLater(client.send(request),
          throwsA(anyOf(isA<ArgumentError>(), isA<ClientException>())));
    });

    test('client.send() GET with empty stream', () async {
      final request = StreamedRequest('GET', Uri.http(host, ''));
      request.headers['Content-Type'] = 'image/png';
      // ignore: unawaited_futures
      request.sink.close();

      final response = await client.send(request);
      expect(response.statusCode, 200);

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next as String;

      expect(serverReceivedContentType, ['image/png']);
      expect(serverReceivedBody.codeUnits, <int>[]);
    });

    test('client.send() GET with stream containing only empty lists', () async {
      final request = StreamedRequest('GET', Uri.http(host, ''));
      request.headers['Content-Type'] = 'image/png';
      request.sink.add([]);
      request.sink.add([]);
      request.sink.add([]);
      // ignore: unawaited_futures
      request.sink.close();

      final response = await client.send(request);
      expect(response.statusCode, 200);

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next as String;

      expect(serverReceivedContentType, ['image/png']);
      expect(serverReceivedBody.codeUnits, <int>[]);
    });

    test('client.send() with persistentConnection', () async {
      // Do five requests to verify that the connection persistence logic is
      // correct.
      for (var i = 0; i < 5; ++i) {
        final request = Request('POST', Uri.http(host, ''))
          ..headers['Content-Type'] = 'text/plain; charset=utf-8'
          ..persistentConnection = true
          ..body = 'Hello World $i';

        final response = await client.send(request);
        expect(response.statusCode, 200);

        final serverReceivedContentType = await httpServerQueue.next;
        final serverReceivedBody = await httpServerQueue.next as String;

        expect(serverReceivedContentType, ['text/plain; charset=utf-8']);
        expect(serverReceivedBody, 'Hello World $i');
      }
    });

    test('client.send() with persistentConnection and body >64K', () async {
      // 64KiB is special for the HTTP network API:
      // https://fetch.spec.whatwg.org/#http-network-or-cache-fetch
      // See https://github.com/dart-lang/http/issues/977
      final body = ''.padLeft(64 * 1024, 'XYZ');

      final request = Request('POST', Uri.http(host, ''))
        ..headers['Content-Type'] = 'text/plain; charset=utf-8'
        ..persistentConnection = true
        ..body = body;

      final response = await client.send(request);
      expect(response.statusCode, 200);

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next as String;

      expect(serverReceivedContentType, ['text/plain; charset=utf-8']);
      expect(serverReceivedBody, body);
    });

    test('client.send() GET with non-empty stream', () async {
      final request = StreamedRequest('GET', Uri.http(host, ''));
      request.headers['Content-Type'] = 'image/png';
      request.sink.add('Hello World!'.codeUnits);
      // ignore: unawaited_futures
      request.sink.close();

      final response = await client.send(request);
      expect(response.statusCode, 200);

      final serverReceivedContentType = await httpServerQueue.next;
      final serverReceivedBody = await httpServerQueue.next as String;

      expect(serverReceivedContentType, ['image/png']);
      expect(serverReceivedBody, 'Hello World!');
      // using io passes, on web body is not transmitted, on cupertino_http
      // exception.
    }, skip: 'unclear semantics for GET requests with body');
  });
}
