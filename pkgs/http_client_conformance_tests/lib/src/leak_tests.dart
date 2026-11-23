// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'leak_server_vm.dart'
    if (dart.library.js_interop) 'leak_server_web.dart';
import 'memory_vm.dart' if (dart.library.js_interop) 'memory_web.dart';
import 'timeline_logging_vm.dart'
    if (dart.library.js_interop) 'timeline_logging_web.dart';

/// The payload size of HTTP requests/responses. It should be small enough to
/// fit into memory.
const _payloadSize = 10 * 1024 * 1024;

/// The number of HTTP requests to make. [_iterations] * [_payloadSize] should
/// be large enough to provoke out-of-memory errors or exceed the RSS growth
/// threshold if the payload is not freed between iterations.
const _iterations = 100;

/// Maximum allowable RSS growth across [_iterations] transfers (half of the
/// total transferred payload size).
const _maxRssGrowth = (_iterations * _payloadSize) ~/ 2;

Uint8List _createPayload(int iteration) {
  final body = Uint8List(_payloadSize);
  // Touch each 4 KB page with a non-zero byte so OS zero-page deduplication
  // and compression cannot hide leaked request buffers from RSS checks.
  for (var offset = 0; offset < body.length; offset += 4096) {
    body[offset] = ((iteration + (offset >> 12)) & 0xff) | 1;
  }
  return body;
}

void _expectNoRssLeak({required int? rssBefore, required int? rssAfter}) {
  if (rssBefore != null && rssAfter != null) {
    final rssGrowth = rssAfter - rssBefore;
    expect(
      rssGrowth,
      lessThan(_maxRssGrowth),
      reason: 'RSS grew by ${rssGrowth ~/ (1024 * 1024)} MB '
          '(${rssBefore ~/ (1024 * 1024)} MB -> '
          '${rssAfter ~/ (1024 * 1024)} MB) after transferring '
          '${(_iterations * _payloadSize) ~/ (1024 * 1024)} MB.',
    );
  }
}

/// Tests that the [Client] does not leak memory or native handles across
/// repeated requests.
///
/// If [supportsAbort] is `false` then tests that assume that requests can be
/// aborted will be skipped.
void testLeaks(Client Function() clientFactory, {bool supportsAbort = false}) {
  group('leaks', () {
    late Client client;
    late String host;
    late StreamChannel<Object?> httpServerChannel;
    late StreamQueue<Object?> httpServerQueue;

    setUpAll(() async {
      client = clientFactory();
      httpServerChannel = await startServer();
      httpServerQueue = StreamQueue(httpServerChannel.stream);
      host = 'localhost:${await httpServerQueue.nextAsInt}';
    });
    tearDownAll(() {
      client.close();
      httpServerChannel.sink.add(null);
    });

    group('request', () {
      test('repeated large request bodies', () async {
        await withoutTimelineLogging(() async {
          final uri = Uri.http(host, '/upload');
          final rssBefore = currentRss();

          for (var i = 0; i < _iterations; ++i) {
            final request = Request('POST', uri)..bodyBytes = _createPayload(i);
            final response = await client.send(request);
            expect(response.statusCode, 200);
            expect(await response.stream.bytesToString(), '$_payloadSize');
          }

          _expectNoRssLeak(rssBefore: rssBefore, rssAfter: currentRss());
        });
      });

      test('repeated large response bodies', () async {
        await withoutTimelineLogging(() async {
          final uri = Uri.http(host, '/download', {'length': '$_payloadSize'});
          final rssBefore = currentRss();

          for (var i = 0; i < _iterations; ++i) {
            final request = Request('GET', uri);
            final response = await client.send(request);
            expect(response.statusCode, 200);
            var received = 0;
            await for (final chunk in response.stream) {
              received += chunk.length;
            }
            expect(received, _payloadSize);
          }

          _expectNoRssLeak(rssBefore: rssBefore, rssAfter: currentRss());
        });
      });
    });

    group('abortable', () {
      test('repeated large request bodies', () async {
        await withoutTimelineLogging(() async {
          final abortCompleter = Completer<void>();
          try {
            final uri = Uri.http(host, '/upload');
            final rssBefore = currentRss();

            for (var i = 0; i < _iterations; ++i) {
              final request = AbortableRequest(
                'POST',
                uri,
                abortTrigger: abortCompleter.future,
              )..bodyBytes = _createPayload(i);
              final response = await client.send(request);
              expect(response.statusCode, 200);
              expect(await response.stream.bytesToString(), '$_payloadSize');
            }

            _expectNoRssLeak(rssBefore: rssBefore, rssAfter: currentRss());
          } finally {
            // Referencing `abortCompleter` after the loop guarantees it stays
            // reachable for all iterations (preventing early GC of pending
            // listeners), verifies completing a trigger after finished requests
            // is a safe no-op, and releases any leaked memory before later
            // tests run.
            abortCompleter.complete();
            await Future<void>.delayed(Duration.zero);
          }
        });
      });

      test('repeated large response bodies', () async {
        await withoutTimelineLogging(() async {
          final abortCompleter = Completer<void>();
          try {
            final uri =
                Uri.http(host, '/download', {'length': '$_payloadSize'});
            final rssBefore = currentRss();

            for (var i = 0; i < _iterations; ++i) {
              final request = AbortableRequest(
                'GET',
                uri,
                abortTrigger: abortCompleter.future,
              );
              final response = await client.send(request);
              expect(response.statusCode, 200);
              var received = 0;
              await for (final chunk in response.stream) {
                received += chunk.length;
              }
              expect(received, _payloadSize);
            }

            _expectNoRssLeak(rssBefore: rssBefore, rssAfter: currentRss());
          } finally {
            // Referencing `abortCompleter` after the loop guarantees it stays
            // reachable for all iterations (preventing early GC of pending
            // listeners), verifies completing a trigger after finished requests
            // is a safe no-op, and releases any leaked memory before later
            // tests run.
            abortCompleter.complete();
            await Future<void>.delayed(Duration.zero);
          }
        });
      });
    }, skip: supportsAbort ? false : 'does not support aborting requests');
  });
}
