// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show ascii;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' show ClientException, Request;
import 'package:http2/multiprotocol_server.dart';
import 'package:http2/src/connection_preface.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/hpack/hpack.dart';
import 'package:http2/src/http2_client.dart';
import 'package:http2/src/settings/settings.dart';
import 'package:http2/transport.dart';
import 'package:test/test.dart';

SecurityContext _serverContext() =>
    SecurityContext()
      ..useCertificateChain('test/certificates/server_chain.pem')
      ..usePrivateKey('test/certificates/server_key.pem', password: 'dartdart');

Future<MultiProtocolHttpServer> _bind() =>
    MultiProtocolHttpServer.bind('localhost', 0, _serverContext());

Http2Client _testClient({
  int maxStreamsPerConnection = 100,
  int maxIdleConnections = 1,
}) => Http2Client(
  maxStreamsPerConnection: maxStreamsPerConnection,
  maxIdleConnections: maxIdleConnections,
  onBadCertificate: (_) => true,
);

/// A minimal HTTP/2-only server that (unlike [MultiProtocolHttpServer])
/// exposes each accepted [ServerTransportConnection], so a test can finish
/// one connection gracefully while the server keeps listening for new ones.
class _RawHttp2Server {
  _RawHttp2Server._(
    this._socket,
    this._settings,
    this._responseDelay,
    this._bodyGate,
  ) {
    _socket.listen((socket) {
      final connection = ServerTransportConnection.viaSocket(
        socket,
        settings: _settings,
      );
      connections.add(connection);
      connection.incomingStreams.listen(
        _respondWith('ok', delay: _responseDelay, bodyGate: _bodyGate),
      );
    });
  }

  /// [settings] defaults to the same value `ServerTransportConnection` would
  /// have applied on its own, so callers that don't care are unaffected.
  static Future<_RawHttp2Server> bind({
    ServerSettings settings = const ServerSettings(concurrentStreamLimit: 1000),
    Future<void>? responseDelay,
    Future<void>? bodyGate,
  }) async {
    final context = _serverContext()..setAlpnProtocols(['h2'], true);
    final socket = await SecureServerSocket.bind('localhost', 0, context);
    return _RawHttp2Server._(socket, settings, responseDelay, bodyGate);
  }

  final SecureServerSocket _socket;
  final ServerSettings _settings;
  final Future<void>? _responseDelay;
  final Future<void>? _bodyGate;
  final connections = <ServerTransportConnection>[];

  int get port => _socket.port;

  Future<void> close() async {
    await _socket.close();
    for (final connection in connections) {
      await connection.terminate();
    }
  }
}

/// Replies with [body] after waiting on [delay], if given.
///
/// [bodyGate] holds the response open *after* its headers have been sent, so a
/// test can observe a request whose headers have arrived but whose stream is
/// still open.
void Function(ServerTransportStream) _respondWith(
  String body, {
  Future<void>? delay,
  Future<void>? bodyGate,
}) {
  return (stream) async {
    final subscription = StreamIterator(stream.incomingMessages);
    await subscription.moveNext(); // Consume the request headers.
    while (await subscription.moveNext()) {} // Drain any request body.

    if (delay != null) await delay;

    stream.outgoingMessages.add(
      HeadersStreamMessage([Header.ascii(':status', '200')]),
    );
    if (bodyGate != null) await bodyGate;
    try {
      stream.outgoingMessages.add(DataStreamMessage(ascii.encode(body)));
      await stream.outgoingMessages.close();
    } catch (_) {}
  };
}

/// A server that speaks HTTP/2 frame by frame, so a test sees exactly which
/// frames the client sends, and when.
class _FrameLevelServer {
  _FrameLevelServer._(this._serverSocket) {
    _serverSocket.listen(_accepted.complete);
  }

  static Future<_FrameLevelServer> start() async {
    final context = _serverContext()..setAlpnProtocols(['h2'], true);
    return _FrameLevelServer._(
      await SecureServerSocket.bind('localhost', 0, context),
    );
  }

  final SecureServerSocket _serverSocket;
  final _accepted = Completer<SecureSocket>();
  late final SecureSocket _socket;
  late final StreamIterator<Frame> _frames;
  late final FrameWriter writer;

  int get port => _serverSocket.port;

  /// Accepts the client's connection and exchanges SETTINGS, then returns the
  /// stream id of the first request, the client's SETTINGS_INITIAL_WINDOW_SIZE
  /// and its connection window.
  Future<(int, {int? streamWindowSetting, int connectionWindowSize})>
  acceptRequest() async {
    _socket = await _accepted.future;
    writer = FrameWriter(HPackEncoder(), _socket, ActiveSettings());
    _frames = StreamIterator(
      FrameReader(
        readConnectionPreface(_socket),
        ActiveSettings(),
      ).startDecoding(),
    );
    // The client only sends its request once it has the server's SETTINGS.
    writer.writeSettingsFrame([]);
    int? streamWindowSetting;
    var connectionWindowSize = 65535;
    while (true) {
      final frame = await nextFrame();
      if (frame is SettingsFrame && !frame.hasAckFlag) {
        for (final setting in frame.settings) {
          if (setting.identifier == Setting.SETTINGS_INITIAL_WINDOW_SIZE) {
            streamWindowSetting = setting.value;
          }
        }
        writer.writeSettingsAckFrame();
      } else if (frame is WindowUpdateFrame && frame.header.streamId == 0) {
        connectionWindowSize += frame.windowSizeIncrement;
      } else if (frame is HeadersFrame) {
        return (
          frame.header.streamId,
          streamWindowSetting: streamWindowSetting,
          connectionWindowSize: connectionWindowSize,
        );
      }
    }
  }

  Future<Frame> nextFrame() async {
    expect(await _frames.moveNext(), isTrue, reason: 'connection closed');
    return _frames.current;
  }

  /// Skips frames until the client grants credit on [streamId].
  Future<WindowUpdateFrame> nextStreamWindowUpdate(int streamId) async {
    while (true) {
      final frame = await nextFrame();
      if (frame is WindowUpdateFrame && frame.header.streamId == streamId) {
        return frame;
      }
    }
  }

  Future<void> close() async {
    await _frames.cancel();
    _socket.destroy();
    await _serverSocket.close();
  }
}

void main() {
  group('http2-client-test', () {
    test('sends-request-and-receives-response', () async {
      final server = await _bind();
      server.startServing(
        (request) {},
        expectAsync1(_respondWith('hello'), count: 1),
      );

      final client = _testClient();
      final response = await client.get(
        Uri.parse('https://localhost:${server.port}/'),
      );

      expect(response.statusCode, 200);
      expect(response.body, 'hello');

      client.close();
      await client.closed;
      await server.close();
    });

    test('pools-connections-per-host-and-port', () async {
      final serverA = await _bind();
      final serverB = await _bind();
      serverA.startServing(
        (request) {},
        expectAsync1(_respondWith('a'), count: 1),
      );
      serverB.startServing(
        (request) {},
        expectAsync1(_respondWith('b'), count: 1),
      );

      final client = _testClient();
      await Future.wait([
        client.get(Uri.parse('https://localhost:${serverA.port}/')),
        client.get(Uri.parse('https://localhost:${serverB.port}/')),
      ]);

      expect(client.connectionCount, 2);

      client.close();
      await client.closed;
      await Future.wait([serverA.close(), serverB.close()]);
    });

    test('exceeding-max-streams-per-connection-opens-new-connection', () async {
      final server = await _bind();
      final releaseA = Completer<void>();
      final releaseB = Completer<void>();
      var requestNr = 0;
      server.startServing(
        (request) {},
        expectAsync1((stream) {
          final release = requestNr++ == 0 ? releaseA : releaseB;
          return _respondWith('r', delay: release.future)(stream);
        }, count: 2),
      );

      final client = _testClient(maxStreamsPerConnection: 1);
      final requestA = client.get(
        Uri.parse('https://localhost:${server.port}/a'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final requestB = client.get(
        Uri.parse('https://localhost:${server.port}/b'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.connectionCount, 2);

      releaseA.complete();
      releaseB.complete();
      await Future.wait([requestA, requestB]);

      client.close();
      await client.closed;
      await server.close();
    });

    test('retries-once-when-pooled-connection-was-closed-by-peer', () async {
      final server = await _RawHttp2Server.bind();
      final client = _testClient();

      final r1 = await client.get(
        Uri.parse('https://localhost:${server.port}/'),
      );
      expect(r1.statusCode, 200);
      expect(client.connectionCount, 1);

      await server.connections.single.finish();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final r2 = await client.get(
        Uri.parse('https://localhost:${server.port}/'),
      );
      expect(r2.statusCode, 200);
      expect(r2.body, 'ok');

      client.close();
      await client.closed;
      await server.close();
    });

    test('respects-server-advertised-max-concurrent-streams', () async {
      final release = Completer<void>();
      final server = await _RawHttp2Server.bind(
        settings: const ServerSettings(concurrentStreamLimit: 1),
        responseDelay: release.future,
      );
      final client = _testClient(
        maxStreamsPerConnection: 100,
        maxIdleConnections: 5,
      );

      final requestA = client.get(
        Uri.parse('https://localhost:${server.port}/a'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final requestB = client.get(
        Uri.parse('https://localhost:${server.port}/b'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      release.complete();
      final responses = await Future.wait([requestA, requestB]);
      expect(responses.map((r) => r.statusCode), everyElement(200));
      expect(server.connections, hasLength(2));

      expect(client.connectionCount, 2);

      client.close();
      await client.closed;
      await server.close();
    });

    test('holds-a-pool-slot-until-the-response-body-completes', () async {
      final gate = Completer<void>();
      final server = await _bind();
      server.startServing(
        (request) {},
        expectAsync1(_respondWith('ok', bodyGate: gate.future), count: 2),
      );

      final client = _testClient(maxStreamsPerConnection: 1);
      final url = Uri.parse('https://localhost:${server.port}/');
      final first = await client.send(Request('GET', url));
      final second = await client.send(Request('GET', url));

      expect(client.connectionCount, 2);

      gate.complete();
      expect(await first.stream.bytesToString(), 'ok');
      expect(await second.stream.bytesToString(), 'ok');

      client.close();
      await client.closed;
      await server.close();
    });

    test('releases-the-slot-when-the-response-body-is-cancelled', () async {
      final gate = Completer<void>();
      final server = await _bind();
      var streamNr = 0;
      server.startServing(
        (request) {},
        expectAsync1((stream) {
          final held = streamNr++ == 0 ? gate.future : null;
          return _respondWith('ok', bodyGate: held)(stream);
        }, count: 2),
      );

      final client = _testClient(maxStreamsPerConnection: 1);
      final url = Uri.parse('https://localhost:${server.port}/');

      final first = await client.send(Request('GET', url));
      await first.stream.listen((_) {}).cancel();

      final second = await client.get(url);
      expect(second.statusCode, 200);
      expect(client.connectionCount, 1);

      gate.complete();
      client.close();
      await client.closed;
      await server.close();
    });

    test('releases-the-slot-when-the-response-body-errors', () async {
      final gate = Completer<void>();
      final server = await _RawHttp2Server.bind(bodyGate: gate.future);
      final client = _testClient(maxStreamsPerConnection: 1);
      final url = Uri.parse('https://localhost:${server.port}/');

      final first = await client.send(Request('GET', url));
      await server.connections.single.terminate();
      await expectLater(
        first.stream.drain<void>(),
        throwsA(isA<ClientException>()),
      );
      // The connection died under the body, so it must have left the pool.
      expect(client.connectionCount, 0);

      gate.complete();

      final second = await client.get(url);
      expect(second.statusCode, 200);

      client.close();
      await client.closed;
      await server.close();
    });

    test('does-not-exceed-the-server-stream-limit-on-a-cold-burst', () async {
      const streamLimit = 2;
      const requestCount = 12;
      final release = Completer<void>();
      final context = _serverContext()..setAlpnProtocols(['h2'], true);
      final socket = await SecureServerSocket.bind('localhost', 0, context);

      final active = <ServerTransportConnection, int>{};
      final peak = <ServerTransportConnection, int>{};
      socket.listen((raw) {
        final connection = ServerTransportConnection.viaSocket(
          raw,
          settings: const ServerSettings(concurrentStreamLimit: streamLimit),
        );
        connection.incomingStreams.listen((stream) async {
          final now = (active[connection] ?? 0) + 1;
          active[connection] = now;
          peak[connection] = max(peak[connection] ?? 0, now);

          final messages = StreamIterator(stream.incomingMessages);
          await messages.moveNext();
          while (await messages.moveNext()) {}
          await release.future;
          stream.outgoingMessages.add(
            HeadersStreamMessage([Header.ascii(':status', '200')]),
          );
          stream.outgoingMessages.add(DataStreamMessage(ascii.encode('ok')));
          await stream.outgoingMessages.close();

          active[connection] = active[connection]! - 1;
        });
      });

      final client = _testClient(maxStreamsPerConnection: 100);
      final url = Uri.parse('https://localhost:${socket.port}/');
      final requests = List.generate(requestCount, (_) => client.get(url));

      await pumpEventQueue();
      release.complete();
      final responses = await Future.wait(requests);

      expect(responses.map((r) => r.statusCode), everyElement(200));
      expect(
        peak.values,
        everyElement(lessThanOrEqualTo(streamLimit)),
        reason: 'no connection may carry more streams than the server allows',
      );

      client.close();
      await client.closed;
      await socket.close();
    });

    test('fails-the-dial-when-the-peer-closes-before-settings', () async {
      final context = _serverContext()..setAlpnProtocols(['h2'], true);
      final socket = await SecureServerSocket.bind('localhost', 0, context);
      socket.listen((connection) => connection.destroy());

      final client = _testClient();
      await expectLater(
        client.get(Uri.parse('https://localhost:${socket.port}/')),
        throwsA(isA<ClientException>()),
      );

      client.close();
      await client.closed;
      await socket.close();
    });

    test('fails-the-dial-when-the-peer-never-sends-settings', () async {
      final context = _serverContext()..setAlpnProtocols(['h2'], true);
      final socket = await SecureServerSocket.bind('localhost', 0, context);
      final held = <SecureSocket>[];
      socket.listen(held.add);

      final client = Http2Client(
        onBadCertificate: (_) => true,
        settingsTimeout: const Duration(milliseconds: 200),
      );
      await expectLater(
        client.get(Uri.parse('https://localhost:${socket.port}/')),
        throwsA(isA<ClientException>()),
      );

      client.close();
      await client.closed;
      for (final connection in held) {
        connection.destroy();
      }
      await socket.close();
    });

    test('close-waits-for-in-flight-request', () async {
      final server = await _bind();
      final release = Completer<void>();
      server.startServing(
        (request) {},
        expectAsync1(_respondWith('done', delay: release.future), count: 1),
      );

      final client = _testClient();
      final request = client.get(
        Uri.parse('https://localhost:${server.port}/'),
      );

      var terminated = false;
      client.close();
      final terminateFuture = client.closed.then((_) {
        terminated = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(terminated, isFalse);

      release.complete();
      await request;
      await terminateFuture;
      expect(terminated, isTrue);

      await server.close();
    });

    test('a-paused-response-body-stops-granting-flow-control-credit', () async {
      const streamWindow = 256 * 1024;
      const connectionWindow = 16 * 1024 * 1024;
      const frameSize = 16 * 1024; // The default SETTINGS_MAX_FRAME_SIZE.

      final server = await _FrameLevelServer.start();
      final client = _testClient();
      final responseFuture = client.send(
        Request('GET', Uri.parse('https://localhost:${server.port}/')),
      );
      final (streamId, :streamWindowSetting, :connectionWindowSize) =
          await server.acceptRequest();
      expect(streamWindowSetting, streamWindow);
      expect(connectionWindowSize, connectionWindow);
      final writer = server.writer;

      writer.writeHeadersFrame(streamId, [
        Header.ascii(':status', '200'),
      ], endStream: false);
      final response = await responseFuture;
      final received = <int>[];
      final body = response.stream.listen(received.addAll)..pause();

      // Everything the client allows without granting more credit, then a
      // PING: the client only answers it once it has processed every frame
      // before it.
      for (var sent = 0; sent < streamWindow; sent += frameSize) {
        writer.writeDataFrame(streamId, Uint8List(frameSize));
      }
      writer.writePingFrame(1);
      while (true) {
        final frame = await server.nextFrame();
        if (frame is PingFrame && frame.hasAckFlag) break;
        if (frame is WindowUpdateFrame && frame.header.streamId == streamId) {
          fail(
            'The client granted ${frame.windowSizeIncrement} bytes of credit '
            'while the response body was paused.',
          );
        }
      }
      expect(received, isEmpty);

      // Resuming lets the client consume the window and grant it back - and,
      // since the body is being read, twice as much again.
      body.resume();
      final frame = await server.nextStreamWindowUpdate(streamId);
      expect(frame.windowSizeIncrement, streamWindow ~/ 2 + streamWindow);

      writer.writeDataFrame(streamId, ascii.encode('end'), endStream: true);
      await body.asFuture<void>();
      expect(received, hasLength(streamWindow + 3));

      client.close();
      await client.closed;
      await server.close();
    });

    test('a-stream-window-doubles-as-the-body-is-read', () async {
      const kib = 1024;
      const total = 8 * 1024 * kib;

      final server = await _FrameLevelServer.start();
      final client = _testClient();
      final responseFuture = client.send(
        Request('GET', Uri.parse('https://localhost:${server.port}/')),
      );
      final (streamId, :streamWindowSetting, connectionWindowSize: _) =
          await server.acceptRequest();
      server.writer.writeHeadersFrame(streamId, [
        Header.ascii(':status', '200'),
      ], endStream: false);
      final response = await responseFuture;
      var received = 0;
      final body = response.stream.listen((chunk) => received += chunk.length);

      // Send as fast as the client's credit allows.
      var window = streamWindowSetting!;
      var largestWindow = window;
      final increments = <int>[];
      var sent = 0;
      while (sent < total) {
        while (window > 0 && sent < total) {
          final size = min(16 * kib, min(window, total - sent));
          sent += size;
          window -= size;
          server.writer.writeDataFrame(
            streamId,
            Uint8List(size),
            endStream: sent == total,
          );
        }
        if (sent == total) break;
        final frame = await server.nextStreamWindowUpdate(streamId);
        increments.add(frame.windowSizeIncrement);
        window += frame.windowSizeIncrement;
        largestWindow = max(largestWindow, window);
      }
      await body.asFuture<void>();
      expect(received, total);

      // Each update acknowledges half the window and doubles it, up to 4 MiB.
      expect(increments.take(4), [
        128 * kib + 256 * kib,
        256 * kib + 512 * kib,
        512 * kib + 1024 * kib,
        1024 * kib + 2048 * kib,
      ]);
      expect(increments.skip(4), everyElement(2048 * kib));
      expect(largestWindow, lessThanOrEqualTo(4096 * kib));

      client.close();
      await client.closed;
      await server.close();
    });

    test('a-response-cancelled-early-had-a-small-window', () async {
      const kib = 1024;

      final server = await _FrameLevelServer.start();
      final client = _testClient();
      final responseFuture = client.send(
        Request('GET', Uri.parse('https://localhost:${server.port}/')),
      );
      final (streamId, :streamWindowSetting, connectionWindowSize: _) =
          await server.acceptRequest();
      server.writer.writeHeadersFrame(streamId, [
        Header.ascii(':status', '200'),
      ], endStream: false);
      final response = await responseFuture;

      // Cancel the body once 256 KiB have been read, like an app abandoning
      // an image that scrolled out of view.
      var received = 0;
      late final StreamSubscription<List<int>> body;
      body = response.stream.listen((chunk) {
        received += chunk.length;
        if (received >= 256 * kib) unawaited(body.cancel());
      });

      // Send as fast as the client's credit allows, until it resets the
      // stream. All of it has to be read off the connection - before the
      // response to any later request on it.
      var window = streamWindowSetting!;
      var sent = 0;
      while (true) {
        while (window > 0) {
          final size = min(16 * kib, window);
          sent += size;
          window -= size;
          server.writer.writeDataFrame(streamId, Uint8List(size));
        }
        final frame = await server.nextFrame();
        if (frame is RstStreamFrame && frame.header.streamId == streamId) {
          break;
        }
        if (frame is WindowUpdateFrame && frame.header.streamId == streamId) {
          window += frame.windowSizeIncrement;
        }
      }
      // 640 KiB: the initial 256 KiB window, then the 128 KiB acknowledged at
      // half of it plus the 256 KiB the window grew by. A fixed 4 MiB window
      // let the server send all 4 MiB at once.
      expect(sent, lessThanOrEqualTo(1024 * kib));

      client.close();
      await client.closed;
      await server.close();
    });

    test(
      'evicts-a-dead-connection-but-keeps-one-whose-stream-was-reset',
      () async {
        final context = _serverContext()..setAlpnProtocols(['h2'], true);
        final socket = await SecureServerSocket.bind('localhost', 0, context);
        final serverConnections = <ServerTransportConnection>[];
        var requestCount = 0;

        socket.listen((raw) {
          final connection = ServerTransportConnection.viaSocket(raw);
          serverConnections.add(connection);
          connection.incomingStreams.listen((stream) async {
            final index = requestCount++;
            await stream.incomingMessages.drain<void>();
            switch (index) {
              case 0:
                // Tear down the whole connection before any response headers.
                await connection.terminate();
              case 1:
                // On a fresh connection: reset only this stream (RST_STREAM),
                // leaving the connection itself healthy.
                stream.terminate();
              default:
                stream.sendHeaders([Header.ascii(':status', '200')]);
                stream.sendData(ascii.encode('reused'), endStream: true);
            }
          });
        });

        final client = _testClient(maxIdleConnections: 1);
        final url = Uri.parse('https://localhost:${socket.port}/');

        await expectLater(client.get(url), throwsA(isA<ClientException>()));
        // The dead connection must have left the pool, not stayed as its one
        // idle connection.
        expect(client.connectionCount, 0);

        await expectLater(client.get(url), throwsA(isA<ClientException>()));
        // A reset of one stream says nothing about the connection.
        expect(client.connectionCount, 1);

        final response = await client.get(url);
        expect(response.statusCode, 200);
        expect(response.body, 'reused');
        expect(serverConnections, hasLength(2));

        client.close();
        await client.closed;
        await socket.close();
      },
    );
  });
}
