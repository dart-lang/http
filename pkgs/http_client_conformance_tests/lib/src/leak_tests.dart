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
import 'timeline_logging_vm.dart'
    if (dart.library.js_interop) 'timeline_logging_web.dart';

/// The payload size of HTTP requests/responses. It should be small enough to
/// fit into memory.
const _payloadSize = 10 * 1024 * 1024;

/// The number of HTTP requests to make. [_iterations] * [_payloadSize] should
/// be large enough to provoke out-of-memory errors if the payload is not
/// garbage collected between iterations.
const _iterations = 100;

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

          for (var i = 0; i < _iterations; ++i) {
            final request = Request('POST', uri)
              ..bodyBytes = Uint8List(_payloadSize);
            final response = await client.send(request);
            expect(response.statusCode, 200);
            expect(await response.stream.bytesToString(), '$_payloadSize');
          }
        });
      });

      test('repeated large response bodies', () async {
        await withoutTimelineLogging(() async {
          final uri = Uri.http(host, '/download', {'length': '$_payloadSize'});

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
        });
      });
    });

    group('abortable', () {
      test('repeated large request bodies', () async {
        await withoutTimelineLogging(() async {
          final abortCompleter = Completer<void>();
          final uri = Uri.http(host, '/upload');

          for (var i = 0; i < _iterations; ++i) {
            final request = AbortableRequest(
              'POST',
              uri,
              abortTrigger: abortCompleter.future,
            )..bodyBytes = Uint8List(_payloadSize);
            final response = await client.send(request);
            expect(response.statusCode, 200);
            expect(await response.stream.bytesToString(), '$_payloadSize');
          }

          abortCompleter.complete();
          await Future<void>.delayed(Duration.zero);
        });
      });

      test('repeated large response bodies', () async {
        await withoutTimelineLogging(() async {
          final abortCompleter = Completer<void>();
          final uri = Uri.http(host, '/download', {'length': '$_payloadSize'});

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

          abortCompleter.complete();
          await Future<void>.delayed(Duration.zero);
        });
      });
    }, skip: supportsAbort ? false : 'does not support aborting requests');
  });
}
