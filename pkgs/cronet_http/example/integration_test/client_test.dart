// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:developer' show reachabilityBarrier;
import 'dart:io';
import 'dart:typed_data';

import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart';
import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:http_profile/http_profile.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jni/jni.dart';
import 'package:test/test.dart';

final _runtimeClass = JClass.forName('java/lang/Runtime');
final _getRuntimeId = _runtimeClass.staticMethodId(
  'getRuntime',
  '()Ljava/lang/Runtime;',
);
final _gcId = _runtimeClass.instanceMethodId('gc', '()V');
final _maxMemoryId = _runtimeClass.instanceMethodId('maxMemory', '()J');
final _systemClass = JClass.forName('java/lang/System');
final _runFinalizationId = _systemClass.staticMethodId(
  'runFinalization',
  '()V',
);

int _javaMaxMemory() => _getRuntimeId(
  _runtimeClass,
  JObject.type,
  [],
).use((runtime) => _maxMemoryId(runtime, jlong.type, []));

void _forceJavaGc() {
  _getRuntimeId(_runtimeClass, JObject.type, []).use((runtime) {
    _gcId(runtime, jvoid.type, []);
    _runFinalizationId(_systemClass, jvoid.type, []);
    _gcId(runtime, jvoid.type, []);
  });
}

@pragma('vm:never-inline')
int _allocateGarbage() {
  final chunks = <Uint8List>[];
  for (var i = 0; i < 16; i++) {
    chunks.add(Uint8List(256 * 1024)..[0] = i);
  }
  return chunks.last[0];
}

Future<void> _forceDartGc() async {
  final barrier = reachabilityBarrier;
  var sink = 0;
  while (reachabilityBarrier <= barrier + 2) {
    sink ^= _allocateGarbage();
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(sink, greaterThanOrEqualTo(0));
}

Future<void> _waitUntilAllCollected(
  List<(String, WeakReference<Object>)> refs,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  var alive = <String>[];
  for (
    var attempt = 0;
    attempt < 3 || DateTime.now().isBefore(deadline);
    attempt++
  ) {
    await _forceDartGc();
    _forceJavaGc();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _forceDartGc();
    alive = [
      for (final (name, ref) in refs)
        if (ref.target != null) name,
    ];
    if (alive.isEmpty) return;
  }
  expect(
    alive,
    isEmpty,
    reason: 'Requests retained after Java and Dart GC: ${alive.join(', ')}',
  );
}

@pragma('vm:never-inline')
Future<WeakReference<BaseRequest>> _runIsolatedRequest(
  BaseRequest Function() createRequest,
  Future<void> Function(BaseRequest request) run,
) async {
  final request = createRequest();
  await run(request);
  return WeakReference(request);
}

@pragma('vm:never-inline')
Future<void> _sendLargeAbortableUpload(
  Client client,
  Uri uri,
  int byteCount,
  Future<void> abortTrigger,
) async {
  final request = AbortableRequest('POST', uri, abortTrigger: abortTrigger)
    ..bodyBytes = Uint8List(byteCount);
  final response = await client.send(request);
  await response.stream.drain<void>();
}

Future<void> testConformance() async {
  group('default cronet engine', () {
    group('profile enabled', () {
      final profile = HttpClientRequestProfile.profilingEnabled;
      HttpClientRequestProfile.profilingEnabled = true;
      try {
        testAll(
          CronetClient.defaultCronetEngine,
          canStreamRequestBody: false,
          canReceiveSetCookieHeaders: true,
          canSendCookieHeaders: true,
          supportsAbort: true,
        );
      } finally {
        HttpClientRequestProfile.profilingEnabled = profile;
      }
    });
    group('profile disabled', () {
      final profile = HttpClientRequestProfile.profilingEnabled;
      HttpClientRequestProfile.profilingEnabled = false;
      try {
        testAll(
          CronetClient.defaultCronetEngine,
          canStreamRequestBody: false,
          canReceiveSetCookieHeaders: true,
          canSendCookieHeaders: true,
          supportsAbort: true,
        );
      } finally {
        HttpClientRequestProfile.profilingEnabled = profile;
      }
    });
  });

  group('from cronet engine', () {
    testAll(
      () {
        final engine = CronetEngine.build(
          cacheMode: CacheMode.disabled,
          userAgent: 'Test Agent (Future)',
        );
        return CronetClient.fromCronetEngine(engine);
      },
      canStreamRequestBody: false,
      canReceiveSetCookieHeaders: true,
      canSendCookieHeaders: true,
      supportsAbort: true,
    );
  });
}

Future<void> testCronetStreamedResponse() async {
  group('CronetStreamedResponse', () {
    late HttpServer server;
    late Uri serverUri;

    setUp(() async {
      server = (await HttpServer.bind('localhost', 0))
        ..listen((request) async {
          await request.drain<void>();
          request.response.headers.set('Content-Type', 'text/plain');
          request.response.headers.set(
            'Cache-Control',
            'public, max-age=30, immutable',
          );
          request.response.headers.set('etag', '12345');
          await request.response.close();
        });
      serverUri = Uri.http('localhost:${server.port}');
    });
    tearDown(() {
      server.close();
    });

    test('negotiatedProtocol', () async {
      final client = CronetClient.defaultCronetEngine();

      final response = await client.send(Request('GET', serverUri));
      await response.stream.drain<void>();

      expect(response.negotiatedProtocol, 'unknown');
    });

    test('receivedByteCount', () async {
      final client = CronetClient.defaultCronetEngine();

      final response = await client.send(Request('GET', serverUri));
      await response.stream.drain<void>();

      expect(response.receivedByteCount, greaterThan(0));
    });

    test('wasCached', () async {
      final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: 1024 * 1024,
      );
      final client = CronetClient.fromCronetEngine(engine);

      final response1 = await client.send(Request('GET', serverUri));
      await response1.stream.drain<void>();
      final response2 = await client.send(Request('GET', serverUri));
      await response2.stream.drain<void>();

      expect(response1.wasCached, isFalse);
      expect(response2.wasCached, isTrue);
    });
  });
}

Future<void> testCronetExceptions() async {
  test('NetworkClientException', () async {
    final server = (await ServerSocket.bind('localhost', 0))
      ..listen((socket) async {
        socket.write('Gibberish');
        await socket.close();
      });
    addTearDown(server.close);
    final client = CronetClient.defaultCronetEngine();
    expect(
      client.send(Request('GET', Uri.http('localhost:${server.port}'))),
      throwsA(
        isA<NetworkException>()
            .having(
              (e) => e.errorCode,
              'errorCode',
              11, // ERROR_OTHER
            )
            .having(
              (e) => e.cronetInternalErrorCode,
              'cronetInternalErrorCode',
              -370, // INVALID_HTTP_RESPONSE
            )
            .having(
              (e) => e.toString(),
              'toString',
              startsWith('NetworkClientException:'),
            ),
      ),
    );
  });

  test('QuicException', () async {
    final udpSocket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(udpSocket.close);

    udpSocket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = udpSocket.receive();
        if (datagram != null) {
          udpSocket.send(
            [0x01, 0x02, 0x03, 0x04],
            datagram.address,
            datagram.port,
          );
        }
      }
    });

    final port = udpSocket.port;

    final engine = CronetEngine.build(
      enableQuic: true,
      quicHints: [('127.0.0.1', port, port)],
    );
    final client = CronetClient.fromCronetEngine(engine);

    expect(
      client.send(Request('GET', Uri.parse('https://127.0.0.1:$port'))),
      throwsA(
        isA<QuicException>()
            .having(
              (e) => e.errorCode,
              'errorCode',
              10, // ERROR_QUIC_PROTOCOL_FAILED
            )
            .having(
              (e) => e.quicDetailedErrorCode,
              'quicDetailedErrorCode',
              isNot(0),
            )
            .having(
              (e) => e.toString(),
              'toString',
              startsWith('QuicException:'),
            ),
      ),
    );
  });

  test('overflowing content-length header throws ClientException', () async {
    final server = (await HttpServer.bind('localhost', 0))
      ..listen((request) async {
        await request.drain<void>();
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.write(
          'HTTP/1.1 200 OK\r\n'
          'Content-Type: text/plain\r\n'
          'Content-Length: 99999999999999999999\r\n'
          'Connection: close\r\n\r\n',
        );
        await socket.close();
      });
    addTearDown(server.close);
    final client = CronetClient.defaultCronetEngine();
    addTearDown(client.close);

    await expectLater(
      client
          .send(Request('GET', Uri.http('localhost:${server.port}')))
          .timeout(const Duration(seconds: 5)),
      throwsA(
        isA<ClientException>().having(
          (e) => e.message,
          'message',
          'Invalid content-length header [99999999999999999999].',
        ),
      ),
    );
  });
}

Future<void> testMemoryLeaks() async {
  group('memory and JNI lifecycle', () {
    late bool previousProfiling;

    setUp(() {
      previousProfiling = HttpClientRequestProfile.profilingEnabled;
      HttpClientRequestProfile.profilingEnabled = false;
    });

    tearDown(() {
      HttpClientRequestProfile.profilingEnabled = previousProfiling;
    });

    test(
      'releases request and JNI callback graph across lifecycles (#2124)',
      () async {
        final serverCancelCompleter = Completer<void>();
        final serverAbortCompleter = Completer<void>();
        late final HttpServer server;
        late final Uri serverUri;
        server = (await HttpServer.bind('localhost', 0))
          ..listen((request) async {
            switch (request.uri.path) {
              case '/ok':
                await request.drain<void>();
                request.response.write('ok');
                await request.response.close();
              case '/echo':
                var received = 0;
                await for (final chunk in request) {
                  received += chunk.length;
                }
                request.response.write('$received');
                await request.response.close();
              case '/stream':
                await request.drain<void>();
                request.response
                  ..bufferOutput = false
                  ..write('Hello World');
                await request.response.flush();
                await serverCancelCompleter.future;
                try {
                  await request.response.close();
                } on IOException {
                  // Expected when the client cancels the active stream.
                }
              case '/abort-stream':
                await request.drain<void>();
                request.response
                  ..bufferOutput = false
                  ..write('Hello World');
                await request.response.flush();
                await serverAbortCompleter.future;
                try {
                  await request.response.close();
                } on IOException {
                  // Expected when the client aborts the active request.
                }
              case '/redirect':
                await request.drain<void>();
                await request.response.redirect(serverUri.replace(path: '/ok'));
              case '/redirect-loop':
                await request.drain<void>();
                await request.response.redirect(
                  serverUri.replace(path: '/redirect-loop'),
                );
              case '/invalid-content-length':
                await request.drain<void>();
                final socket = await request.response.detachSocket(
                  writeHeaders: false,
                );
                socket.write(
                  'HTTP/1.1 200 OK\r\n'
                  'Content-Type: text/plain\r\n'
                  'Content-Length: invalid\r\n'
                  'Connection: close\r\n\r\n',
                );
                await socket.close();
            }
          });
        addTearDown(() async {
          if (!serverCancelCompleter.isCompleted) {
            serverCancelCompleter.complete();
          }
          if (!serverAbortCompleter.isCompleted) {
            serverAbortCompleter.complete();
          }
          await server.close(force: true);
        });
        serverUri = Uri.http('localhost:${server.port}');

        final closedSocket = await ServerSocket.bind('localhost', 0);
        final closedPort = closedSocket.port;
        await closedSocket.close();
        final closedUri = Uri.http('localhost:$closedPort');

        final client = CronetClient.defaultCronetEngine();
        addTearDown(client.close);
        final liveAbortCompleter = Completer<void>();
        final abortCompleter = Completer<void>();

        final refs = <(String, WeakReference<Object>)>[
          (
            'normalGet',
            await _runIsolatedRequest(
              () => Request('GET', serverUri.replace(path: '/ok')),
              (request) async {
                final response = await client.send(request);
                await response.stream.drain<void>();
              },
            ),
          ),
          (
            'abortablePost',
            await _runIsolatedRequest(
              () => AbortableRequest(
                'POST',
                serverUri.replace(path: '/echo'),
                abortTrigger: liveAbortCompleter.future,
              )..bodyBytes = Uint8List(64 * 1024),
              (request) async {
                final response = await client.send(request);
                await response.stream.drain<void>();
              },
            ),
          ),
          (
            'abortedRequest',
            await _runIsolatedRequest(
              () => AbortableRequest(
                'GET',
                serverUri.replace(path: '/abort-stream'),
                abortTrigger: abortCompleter.future,
              ),
              (request) async {
                final response = await client.send(request);
                try {
                  await response.stream.listen((_) {
                    if (!abortCompleter.isCompleted) {
                      abortCompleter.complete();
                    }
                  }).asFuture<void>();
                  fail('Expected RequestAbortedException');
                } on RequestAbortedException {
                  // Expected.
                } finally {
                  if (!serverAbortCompleter.isCompleted) {
                    serverAbortCompleter.complete();
                  }
                }
              },
            ),
          ),
          (
            'cancelStream',
            await _runIsolatedRequest(
              () => Request('GET', serverUri.replace(path: '/stream')),
              (request) async {
                final response = await client.send(request);
                final firstChunk = Completer<void>();
                final subscription = response.stream.listen((_) {
                  if (!firstChunk.isCompleted) {
                    firstChunk.complete();
                  }
                });
                await firstChunk.future;
                await subscription.cancel();
                serverCancelCompleter.complete();
              },
            ),
          ),
          (
            'disallowedRedirect',
            await _runIsolatedRequest(
              () =>
                  Request('GET', serverUri.replace(path: '/redirect'))
                    ..followRedirects = false,
              (request) async {
                final response = await client.send(request);
                await response.stream.drain<void>();
              },
            ),
          ),
          (
            'exceededRedirect',
            await _runIsolatedRequest(
              () => Request('GET', serverUri.replace(path: '/redirect-loop'))
                ..followRedirects = true
                ..maxRedirects = 1,
              (request) async {
                try {
                  await client.send(request);
                  fail('Expected ClientException');
                } on ClientException {
                  // Expected.
                }
              },
            ),
          ),
          (
            'invalidContentLength',
            await _runIsolatedRequest(
              () => Request(
                'GET',
                serverUri.replace(path: '/invalid-content-length'),
              ),
              (request) async {
                try {
                  await client.send(request);
                  fail('Expected ClientException');
                } on ClientException {
                  // Expected.
                }
              },
            ),
          ),
          (
            'failedRequest',
            await _runIsolatedRequest(() => Request('GET', closedUri), (
              request,
            ) async {
              try {
                await client.send(request);
                fail('Expected ClientException');
              } on ClientException {
                // Expected.
              }
            }),
          ),
        ];

        await _waitUntilAllCollected(refs);
        expect(liveAbortCompleter.isCompleted, isFalse);
        liveAbortCompleter.complete();
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'sequential large Abortable uploads do not exhaust Java heap (#1919)',
      () async {
        final server = (await HttpServer.bind('localhost', 0))
          ..listen((request) async {
            await request.drain<void>();
            request.response.write('ok');
            await request.response.close();
          });
        addTearDown(() => server.close(force: true));
        final serverUri = Uri.http('localhost:${server.port}');

        final client = CronetClient.defaultCronetEngine();
        addTearDown(client.close);

        final maxHeap = _javaMaxMemory();
        final effectiveHeap = maxHeap.clamp(0, 512 * 1024 * 1024);
        final chunkSize = (effectiveHeap ~/ 16).clamp(
          4 * 1024 * 1024,
          24 * 1024 * 1024,
        );
        final targetBytes = (effectiveHeap * 5) ~/ 4;
        final iterations = (targetBytes / chunkSize).ceil();
        final liveAbortCompleter = Completer<void>();

        for (var i = 0; i < iterations; i++) {
          await _sendLargeAbortableUpload(
            client,
            serverUri,
            chunkSize,
            liveAbortCompleter.future,
          );
          if ((i + 1) % 4 == 0) {
            _forceJavaGc();
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        }

        expect(liveAbortCompleter.isCompleted, isFalse);
        liveAbortCompleter.complete();
        await Future<void>.delayed(Duration.zero);
      },
    );
  });
}

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  await testConformance();
  await testCronetStreamedResponse();
  await testCronetExceptions();
  await testMemoryLeaks();
}
