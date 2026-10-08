// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http2/src/connection_preface.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/hpack/hpack.dart';
import 'package:http2/src/settings/settings.dart';
import 'package:http2/transport.dart';
import 'package:test/test.dart';

/// The flow-control settings, checked frame by frame against a hand-driven
/// peer: every behaviour here is a statement about what goes on the wire, not
/// about timing.

const _data = 0x0;
const _headers = 0x1;
const _settings = 0x4;
const _ping = 0x6;
const _windowUpdate = 0x8;

const _flagAck = 0x1;
const _flagEndStream = 0x1;
const _flagEndHeaders = 0x4;

const _settingInitialWindowSize = 0x4;
const _settingMaxFrameSize = 0x5;

typedef _Frame = ({int type, int flags, int stream, Uint8List payload});

/// A peer that speaks raw HTTP/2 frames over plain TCP (h2c): it records
/// every frame the client sends and writes whatever frames a test asks for.
class _RawPeer {
  _RawPeer._(this._server);

  final ServerSocket _server;
  late Socket _socket;
  Socket? _clientSocket;
  final frames = <_Frame>[];
  final _buffer = BytesBuilder();
  var _prefaceSeen = false;
  final _connected = Completer<void>();
  final _changed = StreamController<void>.broadcast();

  static Future<_RawPeer> start() async {
    final peer = _RawPeer._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    peer._server.listen((socket) {
      peer._socket = socket;
      peer._connected.complete();
      socket.listen(peer._onBytes);
    });
    return peer;
  }

  Future<ClientTransportConnection> connect(ClientSettings settings) async {
    _clientSocket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      _server.port,
    );
    final client = ClientTransportConnection.viaSocket(
      _clientSocket!,
      settings: settings,
    );
    await _connected.future;
    return client;
  }

  void _onBytes(List<int> bytes) {
    _buffer.add(bytes);
    var all = _buffer.takeBytes();
    if (!_prefaceSeen) {
      if (all.length < 24) {
        _buffer.add(all);
        return;
      }
      all = all.sublist(24); // PRI * HTTP/2.0 ... preface
      _prefaceSeen = true;
    }
    var offset = 0;
    while (all.length - offset >= 9) {
      final length =
          (all[offset] << 16) | (all[offset + 1] << 8) | all[offset + 2];
      if (all.length - offset < 9 + length) break;
      frames.add((
        type: all[offset + 3],
        flags: all[offset + 4],
        stream: ByteData.sublistView(all, offset + 5).getUint32(0) & 0x7fffffff,
        payload: Uint8List.fromList(
          all.sublist(offset + 9, offset + 9 + length),
        ),
      ));
      offset += 9 + length;
    }
    _buffer.add(all.sublist(offset));
    _changed.add(null);
  }

  var _pings = 0;

  /// Resolves once the client has answered a PING sent now. It reads frames
  /// in order and answers a PING as it reads it, so every frame it wrote
  /// before has arrived by then: a deterministic point to check that some
  /// frame was NOT sent.
  Future<void> barrier() async {
    final id = ++_pings;
    send(_ping, 0, 0, (ByteData(8)..setUint32(4, id)).buffer.asUint8List());
    await until(
      () => frames.any(
        (f) =>
            f.type == _ping &&
            f.flags & _flagAck != 0 &&
            ByteData.sublistView(f.payload).getUint32(4) == id,
      ),
    );
  }

  /// Resolves once [test] holds for the frames seen so far.
  Future<void> until(bool Function() test) async {
    while (!test()) {
      await _changed.stream.first.timeout(const Duration(seconds: 5));
    }
  }

  void send(int type, int flags, int stream, List<int> payload) {
    final header =
        ByteData(9)
          ..setUint8(0, payload.length >> 16)
          ..setUint16(1, payload.length & 0xffff)
          ..setUint8(3, type)
          ..setUint8(4, flags)
          ..setUint32(5, stream);
    _socket
      ..add(header.buffer.asUint8List())
      ..add(payload);
  }

  /// The server's own (empty) SETTINGS.
  void sendSettings() => send(_settings, 0, 0, const []);

  void ackSettings() => send(_settings, _flagAck, 0, const []);

  /// `:status: 200` -- HPACK static table index 8.
  void sendOkHeaders(int stream, {bool endStream = false}) => send(
    _headers,
    _flagEndHeaders | (endStream ? _flagEndStream : 0),
    stream,
    const [0x88],
  );

  Future<void> close() async {
    await _changed.close();
    _clientSocket?.destroy();
    _socket.destroy();
    await _server.close();
  }
}

Map<int, int> _settingsOf(_Frame frame) {
  final view = ByteData.sublistView(frame.payload);
  return {
    for (var i = 0; i + 6 <= frame.payload.length; i += 6)
      view.getUint16(i): view.getUint32(i + 2),
  };
}

int _increment(_Frame frame) =>
    ByteData.sublistView(frame.payload).getUint32(0) & 0x7fffffff;

List<Header> _get(String path) => [
  Header.ascii(':method', 'GET'),
  Header.ascii(':path', path),
  Header.ascii(':scheme', 'http'),
  Header.ascii(':authority', 'peer'),
];

void main() {
  late _RawPeer peer;
  late ClientTransportConnection client;
  var connected = false;

  /// Large windows and frames, as a client moving bulk data would choose.
  const tuned = ClientSettings(
    streamWindowSize: 6 << 20,
    connectionWindowSize: 16 << 20,
    maxFrameSize: 1 << 20,
  );

  Future<void> connect(ClientSettings settings) async {
    peer = await _RawPeer.start();
    client = await peer.connect(settings);
    connected = true;
    await peer.until(() => peer.frames.any((f) => f.type == _settings));
  }

  tearDown(() async {
    if (!connected) return;
    connected = false;
    await client.terminate();
    await peer.close();
  });

  test(
    'the defaults send no frame size and grant no connection window',
    () async {
      await connect(const ClientSettings());
      peer.sendSettings();
      await peer.barrier();

      expect(
        _settingsOf(peer.frames.first).keys,
        isNot(contains(_settingMaxFrameSize)),
      );
      expect(peer.frames.where((f) => f.type == _windowUpdate), isEmpty);
    },
  );

  test('the initial SETTINGS carry the stream window and frame size, and '
      'the connection window is raised on stream 0 right after', () async {
    await connect(tuned);
    await peer.until(() => peer.frames.any((f) => f.type == _windowUpdate));

    final settings = peer.frames.first;
    expect(settings.type, _settings);
    expect(
      _settingsOf(settings),
      containsPair(_settingInitialWindowSize, 6 << 20),
    );
    expect(_settingsOf(settings), containsPair(_settingMaxFrameSize, 1 << 20));
    final raise = peer.frames[1];
    expect(raise.type, _windowUpdate);
    expect(raise.stream, 0);
    expect(_increment(raise), (16 << 20) - 65535);
  });

  test('before the SETTINGS are acknowledged, a stream takes one DATA frame '
      'larger than both 16 KiB and 65535 bytes: frame size and stream window '
      'count from the moment they were sent', () async {
    await connect(tuned);
    // No ACK is ever sent.
    peer.sendSettings();
    final stream = client.makeRequest(_get('/one'), endStream: true);
    await peer.until(() => peer.frames.any((f) => f.type == _headers));
    peer
      ..sendOkHeaders(1)
      ..send(_data, _flagEndStream, 1, Uint8List(100000));

    var received = 0;
    await stream.incomingMessages.forEach((m) {
      if (m is DataStreamMessage) received += m.bytes.length;
    });

    expect(received, 100000);
  });

  test('the ACK of our SETTINGS never changes what we SEND on an open '
      'stream; checked with a window below 65535, which is not pre-applied, '
      'so the ACK alone carries the change', () async {
    await connect(const ClientSettings(streamWindowSize: 1000));
    // The peer grants the connection plenty, so only the stream window can
    // hold the upload back.
    peer
      ..sendSettings()
      ..send(_windowUpdate, 0, 0, [0x00, 0x10, 0x00, 0x00]);
    final stream = client.makeRequest([
      Header.ascii(':method', 'POST'),
      Header.ascii(':path', '/upload'),
      Header.ascii(':scheme', 'http'),
      Header.ascii(':authority', 'peer'),
    ]);
    stream.sendData(Uint8List(200000), endStream: true);
    int sent() => peer.frames
        .where((f) => f.type == _data && f.stream == 1)
        .fold<int>(0, (n, f) => n + f.payload.length);
    await peer.until(() => sent() >= 65535);
    peer.ackSettings();
    // The first PING is read after the ACK, possibly in the same read; the
    // second only once the first is answered, so after everything the ACK
    // set off.
    await peer.barrier();
    await peer.barrier();
    expect(sent(), 65535);

    // The peer grants the stream another default window: all of it must be
    // usable, so the ACK of our own smaller window did not shrink the send
    // window.
    peer.send(_windowUpdate, 0, 1, [0x00, 0x00, 0xff, 0xff]);
    await peer.until(() => sent() > 65535);
    await peer.barrier();
    await peer.barrier();
    expect(sent(), 2 * 65535);
  });

  test('with large windows, 4 MiB received costs one WINDOW_UPDATE, not two '
      'per DATA frame', () async {
    await connect(tuned);
    peer
      ..sendSettings()
      ..ackSettings();
    final stream = client.makeRequest(_get('/big'), endStream: true);
    await peer.until(() => peer.frames.any((f) => f.type == _headers));
    final updatesBefore =
        peer.frames.where((f) => f.type == _windowUpdate).length;
    peer.sendOkHeaders(1);
    const frames = (4 << 20) ~/ 16384;
    for (var i = 0; i < frames; i++) {
      peer.send(
        _data,
        i == frames - 1 ? _flagEndStream : 0,
        1,
        Uint8List(16384),
      );
    }

    var received = 0;
    await stream.incomingMessages.forEach((m) {
      if (m is DataStreamMessage) received += m.bytes.length;
    });
    await peer.barrier();

    expect(received, 4 << 20);
    // The stream's half window (3 MiB) was crossed once; the connection's
    // (8 MiB) never. Frame-by-frame acknowledgement sends 512 here.
    final updates =
        peer.frames
            .where((f) => f.type == _windowUpdate)
            .skip(updatesBefore)
            .toList();
    expect([for (final u in updates) u.stream], [1]);
    expect(_increment(updates.single), greaterThanOrEqualTo(3 << 20));
  });

  test('settings outside the ranges of the protocol are refused before the '
      'connection is set up', () {
    for (final settings in [
      const ClientSettings(maxFrameSize: (1 << 14) - 1),
      const ClientSettings(maxFrameSize: 1 << 24),
      const ClientSettings(streamWindowSize: 1 << 31),
      const ClientSettings(connectionWindowSize: 65534),
      const ClientSettings(connectionWindowSize: 1 << 31),
    ]) {
      final outgoing = StreamController<List<int>>();
      expect(
        () => ClientTransportConnection.viaStreams(
          const Stream<List<int>>.empty(),
          outgoing,
          settings: settings,
        ),
        throwsArgumentError,
      );
      unawaited(outgoing.close());
    }
  });

  test('a server with a stream window below 65535 accepts a request sent '
      'before the client read its SETTINGS: until then the client may send '
      'within the default window (RFC 9113 sections 3.4 and 6.9.2)', () async {
    final clientOut = StreamController<List<int>>();
    final fromServer = StreamController<List<int>>();
    Stream<List<int>> toServer() async* {
      yield CONNECTION_PREFACE;
      yield* clientOut.stream;
    }

    final server = ServerTransportConnection.viaStreams(
      toServer(),
      fromServer.sink,
      settings: const ServerSettings(streamWindowSize: 1000),
    );
    final goaways = <GoawayFrame>[];
    FrameReader(fromServer.stream, ActiveSettings()).startDecoding().listen((
      frame,
    ) {
      if (frame is GoawayFrame) goaways.add(frame);
    }, onError: (_) {});

    // SETTINGS, HEADERS and 65535 bytes of DATA in one go, without reading
    // the server's SETTINGS.
    FrameWriter(HPackEncoder(), clientOut.sink, ActiveSettings())
      ..writeSettingsFrame([])
      ..writeHeadersFrame(1, [
        Header.ascii(':method', 'POST'),
        Header.ascii(':path', '/upload'),
        Header.ascii(':scheme', 'http'),
        Header.ascii(':authority', 'peer'),
      ], endStream: false)
      ..writeDataFrame(1, Uint8List(65535), endStream: true);

    var received = 0;
    final stream = await server.incomingStreams.first;
    await stream.incomingMessages.forEach((m) {
      if (m is DataStreamMessage) received += m.bytes.length;
    });

    expect(received, 65535);
    expect(goaways, isEmpty);
    await server.terminate();
  });
}
