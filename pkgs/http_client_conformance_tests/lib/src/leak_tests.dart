// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';
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

/// The number of HTTP requests to make before measuring the starting RSS so
/// that one-time allocations (e.g. JIT compilation, connection setup, and heap
/// growth) are not counted as leaks.
const _warmUpIterations = 10;

/// The number of HTTP requests to make while measuring RSS growth.
/// [_iterations] * [_payloadSize] should be large enough to exceed the RSS
/// growth threshold if the payload is not freed between iterations.
const _iterations = 20;

/// Maximum allowable RSS growth across [_iterations] transfers (half of the
/// total transferred payload size).
const _maxRssGrowth = (_iterations * _payloadSize) ~/ 2;

final _random = Random();

/// Random (and therefore incompressible) bytes. Generated once because it is
/// slow.
final _randomBytes = () {
  final bytes = Uint8List(_payloadSize);
  for (var i = 0; i < bytes.length; ++i) {
    bytes[i] = _random.nextInt(256);
  }
  return bytes;
}();

/// Returns a new copy of [_randomBytes] with one multated byte per page.
/// visible as RSS growth.
Uint8List _createPayload() {
  final payload = Uint8List.fromList(_randomBytes);
  final data = ByteData.sublistView(payload);
  for (var offset = 0; offset < payload.length; offset += 4096) {
    data.setUint32(offset, _random.nextInt(256));
  }
  return payload;
}

// @isTest
void leakTest(Object? description, FutureOr<dynamic> Function() body) {
  test(description, () async {
    expect(
      timelineLoggingEnabled,
      isFalse,
      reason: 'HttpClient.enableTimelineLogging must be disabled because it '
          'retains request and response bodies.',
    );
    for (var i = 0; i < _warmUpIterations; ++i) {
      await body();
    }
    await collectGarbage();
    final rssBefore = currentRss();
    for (var i = 0; i < _iterations; ++i) {
      await body();
    }
    await collectGarbage();
    final rssAfter = currentRss();
    final rssGrowth = rssAfter - rssBefore;
    expect(
      rssGrowth,
      lessThan(_maxRssGrowth),
      reason: 'RSS grew by ${rssGrowth ~/ (1024 * 1024)} MB '
          '(${rssBefore ~/ (1024 * 1024)} MB -> '
          '${rssAfter ~/ (1024 * 1024)} MB) after transferring '
          '${(_iterations * _payloadSize) ~/ (1024 * 1024)} MB.',
    );
  });
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
      leakTest('repeated large request bodies', () async {
        final uri = Uri.http(host, '/upload');

        final request = Request('POST', uri)..bodyBytes = _createPayload();
        final response = await client.send(request);
        expect(response.statusCode, 200);
        expect(await response.stream.bytesToString(), '$_payloadSize');
      });

      leakTest('repeated large response bodies', () async {
        final uri = Uri.http(host, '/download', {'length': '$_payloadSize'});

        final request = Request('GET', uri);
        final response = await client.send(request);
        expect(response.statusCode, 200);
        var received = 0;
        await for (final chunk in response.stream) {
          received += chunk.length;
        }
        expect(received, _payloadSize);
      });
    });

    group('abortable', () {
      // Shared by every request in a test (warm-up, iterations and RSS check)
      // so that abort listeners that outlive their request accumulate and show
      // up as RSS growth. The group's closures keep it reachable, preventing
      // early GC of pending listeners.
      late Completer<void> abortCompleter;

      setUp(() {
        abortCompleter = Completer<void>();
      });

      tearDown(() async {
        // Runs after `leakTest`'s RSS check, even if it fails. Verifies that
        // completing a trigger after finished requests is a safe no-op, and
        // releases any leaked memory before later tests run.
        abortCompleter.complete();
        await Future<void>.delayed(Duration.zero);
      });

      leakTest('repeated large request bodies', () async {
        final uri = Uri.http(host, '/upload');

        final request = AbortableRequest(
          'POST',
          uri,
          abortTrigger: abortCompleter.future,
        )..bodyBytes = _createPayload();
        final response = await client.send(request);
        expect(response.statusCode, 200);
        expect(await response.stream.bytesToString(), '$_payloadSize');
      });

      leakTest('repeated large response bodies', () async {
        final uri = Uri.http(host, '/download', {'length': '$_payloadSize'});

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
      });
    }, skip: supportsAbort ? false : 'does not support aborting requests');
  });
}
