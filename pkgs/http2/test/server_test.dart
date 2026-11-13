// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:http2/src/connection.dart' show Connection;
import 'package:http2/src/connection_preface.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/hpack/hpack.dart';
import 'package:http2/src/settings/settings.dart';
import 'package:http2/src/streams/stream_handler.dart' show StreamHandler;
import 'package:http2/src/sync_errors.dart';
import 'package:http2/transport.dart';
import 'package:test/test.dart';

void main() {
  group('server-tests', () {
    group('normal', () {
      serverTest('gracefull-shutdown-for-unused-connection', (
        ServerTransportConnection server,
        FrameWriter clientWriter,
        StreamIterator<Frame> clientReader,
        Future<Frame> Function() nextFrame,
      ) async {
        Future serverFun() async {
          expect(await server.incomingStreams.toList(), isEmpty);
          await server.finish();
        }

        Future clientFun() async {
          expect(await nextFrame() is SettingsFrame, true);
          clientWriter.writeSettingsAckFrame();
          clientWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);

          // Tell the server to finish.
          clientWriter.writeGoawayFrame(3, ErrorCode.NO_ERROR, []);

          // Make sure the server ended the connection.
          expect(await clientReader.moveNext(), false);
        }

        await Future.wait([serverFun(), clientFun()]);
      });
    });

    group('resource limits', () {
      serverTest('advertises secure defaults', (
        ServerTransportConnection server,
        FrameWriter clientWriter,
        StreamIterator<Frame> clientReader,
        Future<Frame> Function() nextFrame,
      ) async {
        final settingsFrame = await nextFrame() as SettingsFrame;
        final settings = {
          for (final setting in settingsFrame.settings)
            setting.identifier: setting.value,
        };

        expect(
          settings[Setting.SETTINGS_MAX_CONCURRENT_STREAMS],
          defaultMaxConcurrentStreams,
        );
        expect(
          settings[Setting.SETTINGS_MAX_HEADER_LIST_SIZE],
          defaultMaxInboundHeaderListSize,
        );

        clientWriter.writeSettingsAckFrame();
        clientWriter.writeSettingsFrame([]);
        expect(await nextFrame(), isA<SettingsFrame>());
        final termination = server.terminate();
        expect(
          await nextFrame(),
          isA<GoawayFrame>().having(
            (f) => f.errorCode,
            'errorCode',
            ErrorCode.NO_ERROR,
          ),
        );
        expect(await clientReader.moveNext(), isFalse);
        await termination;
      });

      serverTest(
        'enforces peer stream limit and recovers after close',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          final acceptedTwo = Completer<void>();
          final refusalObserved = Completer<void>();

          Future serverFun() async {
            final streams = StreamIterator(server.incomingStreams);
            expect(await streams.moveNext(), isTrue);
            final first = streams.current;
            expect(first.id, 1);
            expect(await streams.moveNext(), isTrue);
            expect(streams.current.id, 3);
            acceptedTwo.complete();

            await refusalObserved.future;
            first.terminate();

            expect(await streams.moveNext(), isTrue);
            expect(streams.current.id, 7);
            await server.terminate();
          }

          Future clientFun() async {
            expect(await nextFrame(), isA<SettingsFrame>());
            // Deliberately withhold the ACK for the server's advertised
            // limits. Local admission must not depend on peer compliance.
            clientWriter.writeSettingsFrame([]);
            expect(await nextFrame(), isA<SettingsFrame>());

            clientWriter.writeHeadersFrame(1, [Header.ascii('a', 'b')]);
            clientWriter.writeHeadersFrame(3, [Header.ascii('a', 'b')]);
            await acceptedTwo.future;

            clientWriter.writeHeadersFrame(5, [Header.ascii('a', 'b')]);
            expect(
              await nextFrame(),
              isA<RstStreamFrame>()
                  .having((f) => f.header.streamId, 'header.streamId', 5)
                  .having(
                    (f) => f.errorCode,
                    'errorCode',
                    ErrorCode.REFUSED_STREAM,
                  ),
            );
            refusalObserved.complete();

            expect(
              await nextFrame(),
              isA<RstStreamFrame>().having(
                (f) => f.header.streamId,
                'header.streamId',
                1,
              ),
            );
            clientWriter.writeHeadersFrame(7, [Header.ascii('a', 'b')]);
            expect(
              await nextFrame(),
              isA<GoawayFrame>().having(
                (f) => f.errorCode,
                'errorCode',
                ErrorCode.NO_ERROR,
              ),
            );
            expect(await clientReader.moveNext(), isFalse);
          }

          await Future.wait([serverFun(), clientFun()]);
        },
        serverSettings: const ServerSettings(
          concurrentStreamLimit: 2,
          maxPeerStreamLimitViolations: 8,
        ),
      );

      serverTest(
        'terminates repeated peer stream-limit violations',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          Future serverFun() async {
            final streams = StreamIterator(server.incomingStreams);
            expect(await streams.moveNext(), isTrue);
            expect(streams.current.id, 1);
            expect(await streams.moveNext(), isFalse);
          }

          Future clientFun() async {
            expect(await nextFrame(), isA<SettingsFrame>());
            clientWriter.writeSettingsAckFrame();
            clientWriter.writeSettingsFrame([]);
            expect(await nextFrame(), isA<SettingsFrame>());

            clientWriter.writeHeadersFrame(1, [Header.ascii('a', 'b')]);
            for (final streamId in [3, 5, 7]) {
              clientWriter.writeHeadersFrame(streamId, [
                Header.ascii('a', 'b'),
              ]);
              expect(
                await nextFrame(),
                isA<RstStreamFrame>()
                    .having(
                      (f) => f.header.streamId,
                      'header.streamId',
                      streamId,
                    )
                    .having(
                      (f) => f.errorCode,
                      'errorCode',
                      ErrorCode.REFUSED_STREAM,
                    ),
              );
            }
            expect(
              await nextFrame(),
              isA<GoawayFrame>().having(
                (f) => f.errorCode,
                'errorCode',
                ErrorCode.ENHANCE_YOUR_CALM,
              ),
            );
            expect(await clientReader.moveNext(), isFalse);
          }

          await Future.wait([serverFun(), clientFun()]);
        },
        serverSettings: const ServerSettings(
          concurrentStreamLimit: 1,
          maxPeerStreamLimitViolations: 3,
        ),
      );

      serverTest(
        'counts stream-limit violations only after settings ACK',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          Future serverFun() async {
            final streams = StreamIterator(server.incomingStreams);
            expect(await streams.moveNext(), isTrue);
            expect(streams.current.id, 1);
            expect(await streams.moveNext(), isFalse);
          }

          Future expectRefused(int streamId) async {
            clientWriter.writeHeadersFrame(streamId, [Header.ascii('a', 'b')]);
            expect(
              await nextFrame(),
              isA<RstStreamFrame>()
                  .having((f) => f.header.streamId, 'header.streamId', streamId)
                  .having(
                    (f) => f.errorCode,
                    'errorCode',
                    ErrorCode.REFUSED_STREAM,
                  ),
            );
          }

          Future clientFun() async {
            expect(await nextFrame(), isA<SettingsFrame>());
            clientWriter.writeSettingsFrame([]);
            expect(await nextFrame(), isA<SettingsFrame>());

            clientWriter.writeHeadersFrame(1, [Header.ascii('a', 'b')]);
            for (final streamId in [3, 5, 7]) {
              await expectRefused(streamId);
            }

            clientWriter.writeSettingsAckFrame();
            for (final streamId in [9, 11, 13]) {
              await expectRefused(streamId);
            }
            expect(
              await nextFrame(),
              isA<GoawayFrame>().having(
                (f) => f.errorCode,
                'errorCode',
                ErrorCode.ENHANCE_YOUR_CALM,
              ),
            );
            expect(await clientReader.moveNext(), isFalse);
          }

          await Future.wait([serverFun(), clientFun()]);
        },
        serverSettings: const ServerSettings(
          concurrentStreamLimit: 1,
          maxPeerStreamLimitViolations: 3,
        ),
      );

      serverTest(
        'rejects an oversized decoded field section before publication',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          Future serverFun() async {
            final streams = StreamIterator(server.incomingStreams);
            expect(await streams.moveNext(), isTrue);
            expect(streams.current.id, 3);
            await server.terminate();
          }

          Future clientFun() async {
            expect(await nextFrame(), isA<SettingsFrame>());
            clientWriter.writeSettingsAckFrame();
            clientWriter.writeSettingsFrame([]);
            expect(await nextFrame(), isA<SettingsFrame>());

            clientWriter.writeHeadersFrame(1, [Header.ascii('a', 'x' * 40)]);
            expect(
              await nextFrame(),
              isA<RstStreamFrame>()
                  .having((f) => f.header.streamId, 'header.streamId', 1)
                  .having(
                    (f) => f.errorCode,
                    'errorCode',
                    ErrorCode.ENHANCE_YOUR_CALM,
                  ),
            );

            clientWriter.writeHeadersFrame(3, [Header.ascii('a', 'b')]);
            expect(await nextFrame(), isA<GoawayFrame>());
            expect(await clientReader.moveNext(), isFalse);
          }

          await Future.wait([serverFun(), clientFun()]);
        },
        serverSettings: const ServerSettings(maxInboundHeaderListSize: 64),
      );

      serverTest('rejects oversized trailers without publishing them', (
        ServerTransportConnection server,
        FrameWriter clientWriter,
        StreamIterator<Frame> clientReader,
        Future<Frame> Function() nextFrame,
      ) async {
        Future serverFun() async {
          final streams = StreamIterator(server.incomingStreams);
          expect(await streams.moveNext(), isTrue);
          final messages = StreamIterator(streams.current.incomingMessages);
          expect(await messages.moveNext(), isTrue);
          final initial = messages.current as HeadersStreamMessage;
          expect(initial.headers, hasLength(1));
          expect(initial.headers.single.value, ascii.encode('b'));
          await expectLater(
            messages.moveNext(),
            throwsA(isA<StreamException>()),
          );
          await server.terminate();
        }

        Future clientFun() async {
          expect(await nextFrame(), isA<SettingsFrame>());
          clientWriter.writeSettingsAckFrame();
          clientWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());

          clientWriter.writeHeadersFrame(1, [
            Header.ascii('a', 'b'),
          ], endStream: false);
          clientWriter.writeHeadersFrame(1, [
            Header.ascii('trailer', 'x' * 40),
          ]);
          expect(
            await nextFrame(),
            isA<RstStreamFrame>()
                .having((f) => f.header.streamId, 'header.streamId', 1)
                .having(
                  (f) => f.errorCode,
                  'errorCode',
                  ErrorCode.ENHANCE_YOUR_CALM,
                ),
          );
          expect(await nextFrame(), isA<GoawayFrame>());
          expect(await clientReader.moveNext(), isFalse);
        }

        await Future.wait([serverFun(), clientFun()]);
      }, serverSettings: const ServerSettings(maxInboundHeaderListSize: 64));

      test('terminates an oversized compressed field block', () async {
        final streams = ClientErrorStreams(
          const ServerSettings(maxInboundHeaderBlockSize: 2),
        );
        final server = streams.serverConnection;
        final incoming = server.incomingStreams.toList();
        final clientReader = streams.clientConnectionFrameReader;

        streams.writeConnectionPreface();

        expect(await clientReader.moveNext(), isTrue);
        expect(clientReader.current, isA<SettingsFrame>());
        streams.writeRawFrame(
          type: FrameType.SETTINGS,
          flags: SettingsFrame.FLAG_ACK,
          streamId: 0,
          payload: const [],
        );
        streams.writeRawFrame(
          type: FrameType.SETTINGS,
          flags: 0,
          streamId: 0,
          payload: const [],
        );
        expect(await clientReader.moveNext(), isTrue);
        expect(clientReader.current, isA<SettingsFrame>());

        streams.writeRawFrame(
          type: FrameType.HEADERS,
          flags: HeadersFrame.FLAG_END_HEADERS,
          streamId: 1,
          payload: [0x84, 0x84, 0x84],
        );

        expect(await clientReader.moveNext(), isTrue);
        expect(
          clientReader.current,
          isA<GoawayFrame>().having(
            (f) => f.errorCode,
            'errorCode',
            ErrorCode.ENHANCE_YOUR_CALM,
          ),
        );
        expect(await clientReader.moveNext(), isFalse);
        expect(await incoming, isEmpty);
      });

      test('terminates an incomplete field block after the timeout', () async {
        final streams = ClientErrorStreams(
          const ServerSettings(
            inboundHeaderBlockTimeout: Duration(milliseconds: 50),
          ),
        );
        final server = streams.serverConnection;
        final incoming = server.incomingStreams.toList();
        final clientReader = streams.clientConnectionFrameReader;

        streams.writeConnectionPreface();

        expect(await clientReader.moveNext(), isTrue);
        expect(clientReader.current, isA<SettingsFrame>());
        streams.writeRawFrame(
          type: FrameType.SETTINGS,
          flags: SettingsFrame.FLAG_ACK,
          streamId: 0,
          payload: const [],
        );
        streams.writeRawFrame(
          type: FrameType.SETTINGS,
          flags: 0,
          streamId: 0,
          payload: const [],
        );
        expect(await clientReader.moveNext(), isTrue);
        expect(clientReader.current, isA<SettingsFrame>());

        streams.writeRawFrame(
          type: FrameType.HEADERS,
          flags: 0,
          streamId: 1,
          payload: [0x84],
        );

        expect(await clientReader.moveNext(), isTrue);
        expect(
          clientReader.current,
          isA<GoawayFrame>().having(
            (f) => f.errorCode,
            'errorCode',
            ErrorCode.ENHANCE_YOUR_CALM,
          ),
        );
        expect(await clientReader.moveNext(), isFalse);
        expect(await incoming, isEmpty);
      });

      test(
        'starts the field-block timeout before payload completion',
        () async {
          final streams = ClientErrorStreams(
            const ServerSettings(
              inboundHeaderBlockTimeout: Duration(milliseconds: 50),
            ),
          );
          final server = streams.serverConnection;
          final incoming = server.incomingStreams.toList();
          final clientReader = streams.clientConnectionFrameReader;

          streams.writeConnectionPreface();

          expect(await clientReader.moveNext(), isTrue);
          expect(clientReader.current, isA<SettingsFrame>());
          streams.writeRawFrame(
            type: FrameType.SETTINGS,
            flags: SettingsFrame.FLAG_ACK,
            streamId: 0,
            payload: const [],
          );
          streams.writeRawFrame(
            type: FrameType.SETTINGS,
            flags: 0,
            streamId: 0,
            payload: const [],
          );
          expect(await clientReader.moveNext(), isTrue);
          expect(clientReader.current, isA<SettingsFrame>());

          streams.writeRawFrameHeader(
            length: 16,
            type: FrameType.HEADERS,
            flags: HeadersFrame.FLAG_END_HEADERS,
            streamId: 1,
          );

          expect(await clientReader.moveNext(), isTrue);
          expect(
            clientReader.current,
            isA<GoawayFrame>().having(
              (f) => f.errorCode,
              'errorCode',
              ErrorCode.ENHANCE_YOUR_CALM,
            ),
          );
          expect(await clientReader.moveNext(), isFalse);
          expect(await incoming, isEmpty);
        },
      );

      test(
        'creates a field-block timer only while a field block is incomplete',
        () async {
          // Tells the field-block timer apart from any other timer.
          const timeout = Duration(seconds: 1234);
          final timers = <Timer>[];
          final spec = ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) {
              final timer = parent.createTimer(zone, duration, callback);
              if (duration == timeout) timers.add(timer);
              return timer;
            },
          );

          await runZoned(() async {
            final streams = ClientErrorStreams(
              const ServerSettings(inboundHeaderBlockTimeout: timeout),
            );
            final server = streams.serverConnection;
            final incoming = StreamIterator(server.incomingStreams);
            final clientReader = streams.clientConnectionFrameReader;

            streams.writeConnectionPreface();

            expect(await clientReader.moveNext(), isTrue);
            expect(clientReader.current, isA<SettingsFrame>());
            streams.writeRawFrame(
              type: FrameType.SETTINGS,
              flags: SettingsFrame.FLAG_ACK,
              streamId: 0,
              payload: const [],
            );
            streams.writeRawFrame(
              type: FrameType.SETTINGS,
              flags: 0,
              streamId: 0,
              payload: const [],
            );
            expect(await clientReader.moveNext(), isTrue);
            expect(clientReader.current, isA<SettingsFrame>());

            // :method GET, :scheme http, :path /
            const fieldBlock = [0x82, 0x86, 0x84];
            const flags =
                HeadersFrame.FLAG_END_HEADERS | HeadersFrame.FLAG_END_STREAM;

            // A field block that is received in full needs no timer.
            streams.writeRawFrame(
              type: FrameType.HEADERS,
              flags: flags,
              streamId: 1,
              payload: fieldBlock,
            );
            expect(await incoming.moveNext(), isTrue);
            expect(incoming.current.id, 1);
            expect(timers, isEmpty);

            // One whose payload is still to come starts the timer, and
            // completing the field block cancels it.
            streams.writeRawFrameHeader(
              length: fieldBlock.length,
              type: FrameType.HEADERS,
              flags: flags,
              streamId: 3,
            );
            await pumpEventQueue();
            expect(timers, hasLength(1));
            expect(timers.single.isActive, isTrue);

            streams.writeB.add(fieldBlock);
            expect(await incoming.moveNext(), isTrue);
            expect(incoming.current.id, 3);
            expect(timers, hasLength(1));
            expect(timers.single.isActive, isFalse);

            final terminated = server.terminate();
            while (await clientReader.moveNext()) {}
            await terminated;
            expect(await incoming.moveNext(), isFalse);
          }, zoneSpecification: spec);
        },
      );

      serverTest(
        'terminates a peer that does not read the acknowledgements of its '
        'pings',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          final queued = await expectTerminatedWhileNotReading(
            server,
            clientWriter,
            clientReader,
            nextFrame,
            () {
              for (var i = 0; i <= FrameWriter.maxQueuedReplyFrames; i++) {
                clientWriter.writePingFrame(i);
              }
            },
          );
          expect(queued, hasLength(FrameWriter.maxQueuedReplyFrames));
          expect(
            queued,
            everyElement(
              isA<PingFrame>().having((f) => f.hasAckFlag, 'hasAckFlag', true),
            ),
          );
        },
      );

      serverTest(
        'terminates a peer that does not read the acknowledgements of its '
        'settings',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          final queued = await expectTerminatedWhileNotReading(
            server,
            clientWriter,
            clientReader,
            nextFrame,
            () {
              for (var i = 0; i <= FrameWriter.maxQueuedReplyFrames; i++) {
                clientWriter.writeSettingsFrame([]);
              }
            },
          );
          expect(queued, hasLength(FrameWriter.maxQueuedReplyFrames));
          expect(
            queued,
            everyElement(
              isA<SettingsFrame>().having(
                (f) => f.hasAckFlag,
                'hasAckFlag',
                true,
              ),
            ),
          );
        },
      );

      serverTest(
        'terminates a peer that does not read the RST_STREAM frames sent in '
        'reply to its frames',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          final queued = await expectTerminatedWhileNotReading(
            server,
            clientWriter,
            clientReader,
            nextFrame,
            () {
              // Every DATA frame on the closed stream 3 is a stream error of
              // type STREAM_CLOSED (RFC 9113 section 6.1), even an empty one,
              // which uses no flow-control window.
              clientWriter
                ..writeHeadersFrame(3, [
                  Header.ascii('a', 'b'),
                ], endStream: false)
                ..writeRstStreamFrame(3, ErrorCode.CANCEL);
              for (var i = 0; i <= FrameWriter.maxQueuedReplyFrames; i++) {
                clientWriter.writeDataFrame(3, const []);
              }
            },
          );
          expect(queued, hasLength(FrameWriter.maxQueuedReplyFrames));
          expect(
            queued,
            everyElement(
              isA<RstStreamFrame>()
                  .having((f) => f.header.streamId, 'header.streamId', 3)
                  .having(
                    (f) => f.errorCode,
                    'errorCode',
                    ErrorCode.STREAM_CLOSED,
                  ),
            ),
          );
        },
      );

      serverTest(
        'terminates a peer that resets the streams it opens too fast',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          // Twice the burst: the bucket refills by just 33 per second while the
          // server handles them.
          const resets = 2 * StreamHandler.maxPeerStreamResetBurst;

          Future serverFun() async {
            var streams = 0;
            await for (final _ in server.incomingStreams) {
              // Only reached if the server let the peer reset all its streams.
              if (++streams == resets) unawaited(server.terminate());
            }
          }

          Future clientFun() async {
            expect(await nextFrame(), isA<SettingsFrame>());
            clientWriter.writeSettingsAckFrame();
            clientWriter.writeSettingsFrame([]);
            expect(await nextFrame(), isA<SettingsFrame>());

            for (var i = 0; i < resets; i++) {
              final streamId = 2 * i + 1;
              clientWriter
                ..writeHeadersFrame(streamId, [
                  Header.ascii('a', 'b'),
                ], endStream: false)
                ..writeRstStreamFrame(streamId, ErrorCode.CANCEL);
            }
            expect(
              await nextFrame(),
              isA<GoawayFrame>().having(
                (f) => f.errorCode,
                'errorCode',
                ErrorCode.ENHANCE_YOUR_CALM,
              ),
            );
            expect(await clientReader.moveNext(), isFalse);
          }

          await Future.wait([serverFun(), clientFun()]);
        },
      );

      serverTest(
        'terminates a peer that makes this endpoint reset the streams it opens '
        'too fast',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          const resets = 2 * StreamHandler.maxPeerStreamResetBurst;
          final terminatedErrorCodes = <int?>[];

          Future serverFun() async {
            var streams = 0;
            await for (final stream in server.incomingStreams) {
              stream.onTerminated = terminatedErrorCodes.add;
              // Only reached if the server let the peer reset all its streams.
              if (++streams == resets) unawaited(server.terminate());
            }
          }

          Future clientFun() async {
            expect(await nextFrame(), isA<SettingsFrame>());
            clientWriter.writeSettingsAckFrame();
            clientWriter.writeSettingsFrame([]);
            expect(await nextFrame(), isA<SettingsFrame>());

            // Open each stream half-closed (END_STREAM) and then send a DATA
            // frame on it: a stream error of type STREAM_CLOSED (RFC 9113
            // section 5.1) that makes the server reset the stream with
            // RST_STREAM ("MadeYouReset", CVE-2025-8671). Read the replies so
            // maxQueuedReplyFrames is never reached.
            Frame? terminal;
            for (var i = 0; i < resets && terminal == null; i++) {
              final streamId = 2 * i + 1;
              clientWriter
                ..writeHeadersFrame(streamId, [
                  Header.ascii('a', 'b'),
                ], endStream: true)
                ..writeDataFrame(streamId, const []);
              final reply = await nextFrame();
              if (reply is GoawayFrame) {
                terminal = reply;
              } else {
                expect(
                  reply,
                  isA<RstStreamFrame>().having(
                    (f) => f.errorCode,
                    'errorCode',
                    ErrorCode.STREAM_CLOSED,
                  ),
                );
              }
            }
            terminal ??= await nextFrame();
            expect(
              terminal,
              isA<GoawayFrame>().having(
                (f) => f.errorCode,
                'errorCode',
                ErrorCode.ENHANCE_YOUR_CALM,
              ),
            );
            expect(await clientReader.moveNext(), isFalse);
            expect(terminatedErrorCodes, isNotEmpty);
            expect(terminatedErrorCodes, everyElement(ErrorCode.STREAM_CLOSED));
          }

          await Future.wait([serverFun(), clientFun()]);
        },
      );

      serverTest(
        'counts peer streams whose response is blocked on a zero window',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          Future serverFun() async {
            await for (final stream in server.incomingStreams) {
              await stream.incomingMessages.drain<void>();
              stream
                ..sendHeaders([Header.ascii(':status', '200')])
                ..sendData([1, 2, 3, 4, 5], endStream: true);
            }
          }

          Future clientFun() async {
            try {
              expect(await nextFrame(), isA<SettingsFrame>());
              clientWriter.writeSettingsAckFrame();
              // Zero initial window: the server can send HEADERS, but its
              // END_STREAM DATA stays queued, so the streams remain half-closed
              // (remote) on the wire (RFC 9113 section 5.1, CVE-2023-26964 /
              // CVE-2023-45802).
              clientWriter.writeSettingsFrame([
                Setting(Setting.SETTINGS_INITIAL_WINDOW_SIZE, 0),
              ]);
              expect(await nextFrame(), isA<SettingsFrame>());

              for (final streamId in [1, 3]) {
                clientWriter.writeHeadersFrame(streamId, [
                  Header.ascii('a', 'b'),
                ], endStream: true);
                expect(
                  await nextFrame(),
                  isA<HeadersFrame>().having(
                    (f) => f.header.streamId,
                    'header.streamId',
                    streamId,
                  ),
                );
              }

              // Stream 5 exceeds concurrentStreamLimit (2) because streams 1
              // and 3 have not sent END_STREAM yet.
              clientWriter.writeHeadersFrame(5, [
                Header.ascii('a', 'b'),
              ], endStream: true);
              expect(
                await nextFrame(),
                isA<RstStreamFrame>()
                    .having((f) => f.header.streamId, 'header.streamId', 5)
                    .having(
                      (f) => f.errorCode,
                      'errorCode',
                      ErrorCode.REFUSED_STREAM,
                    ),
              );

              // Granting window credit to stream 1 lets its END_STREAM DATA go
              // out, freeing a slot for stream 7.
              clientWriter.writeWindowUpdate(5, streamId: 1);
              expect(
                await nextFrame(),
                isA<DataFrame>()
                    .having((f) => f.header.streamId, 'header.streamId', 1)
                    .having(
                      (f) => f.hasEndStreamFlag,
                      'hasEndStreamFlag',
                      isTrue,
                    ),
              );

              clientWriter.writeHeadersFrame(7, [
                Header.ascii('a', 'b'),
              ], endStream: true);
              expect(
                await nextFrame(),
                isA<HeadersFrame>().having(
                  (f) => f.header.streamId,
                  'header.streamId',
                  7,
                ),
              );
            } finally {
              unawaited(server.terminate());
            }
            while (await clientReader.moveNext()) {}
          }

          await Future.wait([serverFun(), clientFun()]);
        },
        serverSettings: const ServerSettings(concurrentStreamLimit: 2),
      );

      serverTest(
        'sends empty end-stream DATA when the peer stream window is negative',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          final shrunkWindow = Completer<void>();

          Future serverFun() async {
            try {
              final streams = StreamIterator(server.incomingStreams);
              expect(await streams.moveNext(), isTrue);
              final stream = streams.current;
              await stream.incomingMessages.drain<void>();
              stream
                ..sendHeaders([Header.ascii(':status', '200')])
                ..sendData([1, 2, 3, 4, 5]);
              await shrunkWindow.future;
              // Closing outgoingMessages sends a 0-byte DATA frame with
              // END_STREAM, which RFC 9113 section 6.9.1 permits even when the
              // send window is zero or negative.
              await stream.outgoingMessages.close();
              await server.finish();
            } catch (_) {
              unawaited(server.terminate());
              rethrow;
            }
          }

          Future clientFun() async {
            expect(await nextFrame(), isA<SettingsFrame>());
            clientWriter.writeSettingsAckFrame();
            clientWriter.writeSettingsFrame([
              Setting(Setting.SETTINGS_INITIAL_WINDOW_SIZE, 5),
            ]);
            expect(await nextFrame(), isA<SettingsFrame>());

            clientWriter.writeHeadersFrame(1, [
              Header.ascii('a', 'b'),
            ], endStream: true);
            expect(await nextFrame(), isA<HeadersFrame>());
            expect(await nextFrame(), isA<DataFrame>());

            // Lowering SETTINGS_INITIAL_WINDOW_SIZE to 0 makes stream 1's send
            // window -5 (RFC 9113 section 6.9.2).
            clientWriter.writeSettingsFrame([
              Setting(Setting.SETTINGS_INITIAL_WINDOW_SIZE, 0),
            ]);
            expect(await nextFrame(), isA<SettingsFrame>());
            shrunkWindow.complete();

            expect(
              await nextFrame(),
              isA<DataFrame>()
                  .having((f) => f.bytes, 'bytes', isEmpty)
                  .having(
                    (f) => f.hasEndStreamFlag,
                    'hasEndStreamFlag',
                    isTrue,
                  ),
            );
            expect(
              await nextFrame(),
              isA<GoawayFrame>().having(
                (f) => f.errorCode,
                'errorCode',
                ErrorCode.NO_ERROR,
              ),
            );
            expect(await clientReader.moveNext(), isFalse);
          }

          await Future.wait([serverFun(), clientFun()]);
        },
      );

      serverTest(
        'enforces connection flow control on ignored DATA and does not inflate '
        'the receive window',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          final sub = server.incomingStreams.listen((_) {});
          expect(await nextFrame(), isA<SettingsFrame>());
          clientWriter.writeSettingsAckFrame();
          clientWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());

          // Ignored DATA on non-existent stream 3 is replenished, so the
          // connection window stays 65535 - it must not grow to 65535 + 10000.
          clientWriter.writeDataFrame(3, List<int>.filled(10000, 0));
          expect(await nextFrame(), isA<WindowUpdateFrame>());
          expect(await nextFrame(), isA<RstStreamFrame>());

          // Open stream 1 without reading its incomingMessages, then send
          // 65536 bytes (> 65535 connection window) across frames.
          clientWriter
            ..writeHeadersFrame(1, [Header.ascii('a', 'b')], endStream: false)
            ..writeDataFrame(1, List<int>.filled(16384, 0))
            ..writeDataFrame(1, List<int>.filled(16384, 0))
            ..writeDataFrame(1, List<int>.filled(16384, 0))
            ..writeDataFrame(1, List<int>.filled(16384, 0));
          final frameFuture = nextFrame();
          await pumpEventQueue();
          // Only reached if the server inflated its receive window above 65535.
          unawaited(server.terminate());

          expect(
            await frameFuture,
            isA<GoawayFrame>().having(
              (f) => f.errorCode,
              'errorCode',
              ErrorCode.FLOW_CONTROL_ERROR,
            ),
          );
          await sub.cancel();
        },
      );

      test('counts DATA padding toward flow control and checks stream window '
          'while paused', () async {
        final streams = ClientErrorStreams(
          const ServerSettings(streamWindowSize: 100),
        );
        final server = streams.serverConnection;
        final sub = server.incomingStreams.listen((_) {});
        final clientReader = streams.clientConnectionFrameReader;

        Future<Frame> nextFrame() async {
          expect(await clientReader.moveNext(), isTrue);
          return clientReader.current;
        }

        streams.writeConnectionPreface();
        expect(await nextFrame(), isA<SettingsFrame>());
        streams.writeRawFrame(
          type: FrameType.SETTINGS,
          flags: SettingsFrame.FLAG_ACK,
          streamId: 0,
          payload: const [],
        );
        streams.writeRawFrame(
          type: FrameType.SETTINGS,
          flags: 0,
          streamId: 0,
          payload: const [],
        );
        expect(await nextFrame(), isA<SettingsFrame>());

        // Open stream 1 without reading its incomingMessages, then send a
        // padded 0-data DATA frame whose 1-byte Pad Length + 100 pad bytes
        // (101 bytes total) exceed the 100-byte stream window (RFC 9113
        // section 6.1).
        final frameFuture = nextFrame();
        streams.writeRawFrame(
          type: FrameType.HEADERS,
          flags: HeadersFrame.FLAG_END_HEADERS,
          streamId: 1,
          payload: HPackEncoder().encode([Header.ascii('a', 'b')]),
        );
        streams.writeRawFrame(
          type: FrameType.DATA,
          flags: DataFrame.FLAG_PADDED,
          streamId: 1,
          payload: [100, ...List<int>.filled(100, 0)],
        );
        await pumpEventQueue();
        unawaited(server.terminate());

        expect(
          await frameFuture,
          isA<GoawayFrame>().having(
            (f) => f.errorCode,
            'errorCode',
            ErrorCode.FLOW_CONTROL_ERROR,
          ),
        );
        await sub.cancel();
      });

      serverTest('rejects a SETTINGS frame with too many entries', (
        ServerTransportConnection server,
        FrameWriter clientWriter,
        StreamIterator<Frame> clientReader,
        Future<Frame> Function() nextFrame,
      ) async {
        final sub = server.incomingStreams.listen((_) {});
        expect(await nextFrame(), isA<SettingsFrame>());
        clientWriter.writeSettingsAckFrame();
        clientWriter.writeSettingsFrame([]);
        expect(await nextFrame(), isA<SettingsFrame>());

        // CVE-2020-11080: a single SETTINGS frame carrying more than
        // maxSettingsPerFrame entries is rejected with ENHANCE_YOUR_CALM.
        clientWriter.writeSettingsFrame(
          List<Setting>.filled(
            SettingsHandler.maxSettingsPerFrame + 1,
            Setting(Setting.SETTINGS_INITIAL_WINDOW_SIZE, 65535),
          ),
        );
        expect(
          await nextFrame(),
          isA<GoawayFrame>().having(
            (f) => f.errorCode,
            'errorCode',
            ErrorCode.ENHANCE_YOUR_CALM,
          ),
        );
        await sub.cancel();
      });

      serverTest(
        'terminates a peer that floods control frames while reading replies',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          const floodFrames = 2 * Connection.maxControlFrameBurst;
          final sub = server.incomingStreams.listen((_) {});
          expect(await nextFrame(), isA<SettingsFrame>());
          clientWriter.writeSettingsAckFrame();
          clientWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());

          // CVE-2019-9512: send non-ACK PING frames while draining every PING
          // ACK so maxQueuedReplyFrames is never reached.
          Frame? terminal;
          for (var i = 0; i < floodFrames && terminal == null; i++) {
            clientWriter.writePingFrame(i);
            final reply = await nextFrame();
            if (reply is GoawayFrame) {
              terminal = reply;
            } else {
              expect(
                reply,
                isA<PingFrame>().having(
                  (f) => f.hasAckFlag,
                  'hasAckFlag',
                  true,
                ),
              );
            }
          }
          if (terminal == null) {
            unawaited(server.terminate());
            terminal = await nextFrame();
          }
          expect(
            terminal,
            isA<GoawayFrame>().having(
              (f) => f.errorCode,
              'errorCode',
              ErrorCode.ENHANCE_YOUR_CALM,
            ),
          );
          await sub.cancel();
        },
      );

      serverTest(
        'rejects zero WINDOW_UPDATE increments and scopes stream overflow to '
        'the stream',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          final sub = server.incomingStreams.listen((_) {});
          expect(await nextFrame(), isA<SettingsFrame>());
          clientWriter.writeSettingsAckFrame();
          clientWriter.writeSettingsFrame([]);
          expect(await nextFrame(), isA<SettingsFrame>());

          clientWriter
            ..writeHeadersFrame(1, [Header.ascii('a', 'b')], endStream: false)
            ..writeHeadersFrame(3, [Header.ascii('a', 'b')], endStream: false)
            ..writeHeadersFrame(5, [Header.ascii('a', 'b')], endStream: false);

          // RFC 9113 section 6.9: zero increment on a stream is a stream error
          // of type PROTOCOL_ERROR.
          clientWriter
            ..writeWindowUpdate(0, streamId: 1)
            ..writePingFrame(1);
          expect(
            await nextFrame(),
            isA<RstStreamFrame>()
                .having((f) => f.header.streamId, 'header.streamId', 1)
                .having(
                  (f) => f.errorCode,
                  'errorCode',
                  ErrorCode.PROTOCOL_ERROR,
                ),
          );
          expect(await nextFrame(), isA<PingFrame>());

          // RFC 9113 section 6.9.1: overflowing a stream window (> 2^31 - 1)
          // resets only that stream with FLOW_CONTROL_ERROR, leaving stream 5
          // open.
          clientWriter.writeWindowUpdate(0x7fffffff, streamId: 3);
          expect(
            await nextFrame(),
            isA<RstStreamFrame>()
                .having((f) => f.header.streamId, 'header.streamId', 3)
                .having(
                  (f) => f.errorCode,
                  'errorCode',
                  ErrorCode.FLOW_CONTROL_ERROR,
                ),
          );

          // RFC 9113 section 6.9: zero increment on stream 0 is a connection
          // error of type PROTOCOL_ERROR.
          final frameFuture = nextFrame();
          clientWriter.writeWindowUpdate(0, streamId: 0);
          await pumpEventQueue();
          unawaited(server.terminate());
          expect(
            await frameFuture,
            isA<GoawayFrame>().having(
              (f) => f.errorCode,
              'errorCode',
              ErrorCode.PROTOCOL_ERROR,
            ),
          );
          await sub.cancel();
        },
      );

      serverTest(
        'propagates connection backpressure to outgoing stream producers',
        (
          ServerTransportConnection server,
          FrameWriter clientWriter,
          StreamIterator<Frame> clientReader,
          Future<Frame> Function() nextFrame,
        ) async {
          const totalChunks = 50;
          const chunkSize = 16384;
          var chunksProduced = 0;
          var pausedCount = 0;

          Future serverFun() async {
            await for (final stream in server.incomingStreams) {
              unawaited(stream.incomingMessages.drain<void>());
              late final StreamController<StreamMessage> producer;
              var pumping = false;
              void pump() {
                if (pumping || producer.isPaused) return;
                if (chunksProduced >= totalChunks) {
                  if (!producer.isClosed) unawaited(producer.close());
                  return;
                }
                pumping = true;
                chunksProduced++;
                producer.add(
                  DataStreamMessage(
                    List<int>.filled(chunkSize, 0x42),
                    endStream: chunksProduced == totalChunks,
                  ),
                );
                Future.microtask(() {
                  pumping = false;
                  pump();
                });
              }

              producer = StreamController<StreamMessage>(
                onListen: () {
                  producer.add(
                    HeadersStreamMessage([Header.ascii(':status', '200')]),
                  );
                  pump();
                },
                onPause: () {
                  pausedCount++;
                },
                onResume: pump,
              );
              await stream.outgoingMessages.addStream(producer.stream);
              await stream.outgoingMessages.close();
            }
          }

          Future clientFun() async {
            try {
              expect(await nextFrame(), isA<SettingsFrame>());
              clientWriter.writeSettingsAckFrame();
              // Grant a huge per-stream window so only the 65,535-byte
              // connection window restrains the response (CVE-2019-9517).
              clientWriter.writeSettingsFrame([
                Setting(Setting.SETTINGS_INITIAL_WINDOW_SIZE, 0x7fffffff),
              ]);
              expect(await nextFrame(), isA<SettingsFrame>());

              clientWriter.writeHeadersFrame(1, [
                Header.ascii('a', 'b'),
              ], endStream: true);
              expect(await nextFrame(), isA<HeadersFrame>());

              var received = 0;
              while (received < 65535) {
                final data = await nextFrame() as DataFrame;
                received += data.bytes.length;
              }
              await pumpEventQueue();

              // With the 65,535-byte connection window exhausted, the server's
              // outgoing producer must have paused rather than buffering all 50
              // chunks internally.
              expect(pausedCount, greaterThan(0));
              expect(chunksProduced, lessThan(10));

              clientWriter.writeWindowUpdate(
                totalChunks * chunkSize,
                streamId: 0,
              );
              while (received < totalChunks * chunkSize) {
                final data = await nextFrame() as DataFrame;
                received += data.bytes.length;
              }
              expect(received, totalChunks * chunkSize);
              final finished = server.finish();
              expect(await nextFrame(), isA<GoawayFrame>());
              expect(await clientReader.moveNext(), isFalse);
              await finished;
            } finally {
              unawaited(server.terminate());
            }
          }

          await Future.wait([serverFun(), clientFun()]);
        },
      );

      serverTest('terminates a peer that does not read WINDOW_UPDATE replies', (
        ServerTransportConnection server,
        FrameWriter clientWriter,
        StreamIterator<Frame> clientReader,
        Future<Frame> Function() nextFrame,
      ) async {
        final queued = await expectTerminatedWhileNotReading(
          server,
          clientWriter,
          clientReader,
          nextFrame,
          () {
            // Each 1-byte DATA frame on open stream 1 triggers two
            // WINDOW_UPDATE replies (stream 0 and stream 1).
            for (var i = 0; i <= FrameWriter.maxQueuedReplyFrames ~/ 2; i++) {
              clientWriter.writeDataFrame(1, const [1]);
            }
          },
        );
        expect(queued, hasLength(FrameWriter.maxQueuedReplyFrames));
        expect(queued, everyElement(isA<WindowUpdateFrame>()));
      });
    });

    group('client-errors', () {
      serverTest('no-settings-frame-at-beginning', (
        ServerTransportConnection server,
        FrameWriter clientWriter,
        StreamIterator<Frame> clientReader,
        Future<Frame> Function() nextFrame,
      ) async {
        Future serverFun() async {
          // TODO: Do we want to get an error in this case?
          expect(await server.incomingStreams.toList(), isEmpty);
          await server.finish();
        }

        Future clientFun() async {
          expect(await nextFrame() is SettingsFrame, true);

          // Write headers frame to open a new stream
          clientWriter.writeHeadersFrame(1, [], endStream: true);

          // Make sure the client gets a [GoawayFrame] frame.
          expect(
            await nextFrame(),
            isA<GoawayFrame>().having(
              (f) => f.errorCode,
              'errorCode',
              ErrorCode.PROTOCOL_ERROR,
            ),
          );

          // Make sure the server ended the connection.
          expect(await clientReader.moveNext(), false);
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      serverTest('data-frame-for-invalid-stream', (
        ServerTransportConnection server,
        FrameWriter clientWriter,
        StreamIterator<Frame> clientReader,
        Future<Frame> Function() nextFrame,
      ) async {
        Future serverFun() async {
          await server.incomingStreams.toList();
          await server.finish();
        }

        Future clientFun() async {
          expect(await nextFrame() is SettingsFrame, true);
          clientWriter.writeSettingsAckFrame();
          clientWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);

          // Write data frame to non-existent stream.
          clientWriter.writeDataFrame(3, [1, 2, 3]);

          // Make sure the client gets a [RstStreamFrame] frame.
          var frame = await nextFrame();
          expect(frame is WindowUpdateFrame, true);
          expect(
            await nextFrame(),
            isA<RstStreamFrame>()
                .having(
                  (f) => f.errorCode,
                  'errorCode',
                  ErrorCode.STREAM_CLOSED,
                )
                .having((f) => f.header.streamId, 'header.streamId', 3),
          );

          // Tell the server to finish.
          clientWriter.writeGoawayFrame(3, ErrorCode.NO_ERROR, []);

          // Make sure the server ended the connection.
          expect(await clientReader.moveNext(), false);
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      serverTest('data-frame-after-stream-closed', (
        ServerTransportConnection server,
        FrameWriter clientWriter,
        StreamIterator<Frame> clientReader,
        Future<Frame> Function() nextFrame,
      ) async {
        Future serverFun() async {
          await server.incomingStreams.toList();
          await server.finish();
        }

        Future clientFun() async {
          expect(await nextFrame() is SettingsFrame, true);
          clientWriter.writeSettingsAckFrame();
          clientWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);

          clientWriter.writeHeadersFrame(3, [
            Header.ascii('a', 'b'),
          ], endStream: true);

          // Write data frame to non-existent stream (stream 3 was closed
          // above).
          clientWriter.writeDataFrame(3, [1, 2, 3]);

          // Make sure the client gets a [RstStreamFrame] frame.
          expect(
            await nextFrame(),
            isA<RstStreamFrame>()
                .having(
                  (f) => f.errorCode,
                  'errorCode',
                  ErrorCode.STREAM_CLOSED,
                )
                .having((f) => f.header.streamId, 'header.streamId', 3),
          );

          // Tell the server to finish.
          clientWriter.writeGoawayFrame(3, ErrorCode.NO_ERROR, []);

          // Make sure the server ended the connection.
          expect(await clientReader.moveNext(), false);
        }

        await Future.wait([serverFun(), clientFun()]);
      });

      test(
        'ignores-priority-and-unknown-frames-on-open-and-idle-streams',
        () async {
          final streams = ClientErrorStreams();
          final server = streams.serverConnection;
          final clientReader = streams.clientConnectionFrameReader;
          final encoder = HPackEncoder();

          Future<Frame> nextFrame() async {
            expect(await clientReader.moveNext(), isTrue);
            return clientReader.current;
          }

          Future<void> serverFun() async {
            final it = StreamIterator(server.incomingStreams);
            expect(await it.moveNext(), isTrue);
            final stream = it.current;
            final messages = await stream.incomingMessages.toList();
            expect(messages, hasLength(2));
            expect(messages[0], isA<HeadersStreamMessage>());
            expect(messages[1], isA<DataStreamMessage>());
            stream.sendHeaders([
              Header.ascii(':status', '200'),
            ], endStream: true);
            expect(await it.moveNext(), isFalse);
            await server.finish();
          }

          Future<void> clientFun() async {
            streams.writeConnectionPreface();
            expect(await nextFrame(), isA<SettingsFrame>());
            streams.writeRawFrame(
              type: FrameType.SETTINGS,
              flags: SettingsFrame.FLAG_ACK,
              streamId: 0,
              payload: const [],
            );
            streams.writeRawFrame(
              type: FrameType.SETTINGS,
              flags: 0,
              streamId: 0,
              payload: const [],
            );
            expect(await nextFrame(), isA<SettingsFrame>());

            streams.writeRawFrame(
              type: FrameType.HEADERS,
              flags: HeadersFrame.FLAG_END_HEADERS,
              streamId: 1,
              payload: encoder.encode([Header.ascii('a', 'b')]),
            );
            // Send PRIORITY on open stream 1 and unknown frame (0xfa) on open
            // stream 1 and idle stream 5.
            streams.writeRawFrame(
              type: FrameType.PRIORITY,
              flags: 0,
              streamId: 1,
              payload: const [0, 0, 0, 0, 16],
            );
            streams.writeRawFrame(
              type: 0xfa,
              flags: 0,
              streamId: 1,
              payload: const [1, 2],
            );
            streams.writeRawFrame(
              type: 0xfa,
              flags: 0,
              streamId: 5,
              payload: const [],
            );
            streams.writeRawFrame(
              type: FrameType.DATA,
              flags: DataFrame.FLAG_END_STREAM,
              streamId: 1,
              payload: const [42],
            );

            expect(await nextFrame(), isA<WindowUpdateFrame>());
            expect(await nextFrame(), isA<WindowUpdateFrame>());
            expect(await nextFrame(), isA<HeadersFrame>());

            streams.writeRawFrame(
              type: FrameType.GOAWAY,
              flags: 0,
              streamId: 0,
              payload: const [0, 0, 0, 1, 0, 0, 0, 0],
            );
            expect(await clientReader.moveNext(), isFalse);
          }

          await Future.wait([serverFun(), clientFun()]);
        },
      );

      test('rejects-control-frames-with-nonzero-stream-id', () async {
        for (final frameType in [
          FrameType.SETTINGS,
          FrameType.PING,
          FrameType.GOAWAY,
        ]) {
          final streams = ClientErrorStreams();
          final server = streams.serverConnection;
          final incoming = server.incomingStreams.toList();
          final clientReader = streams.clientConnectionFrameReader;

          Future<Frame> nextFrame() async {
            expect(await clientReader.moveNext(), isTrue);
            return clientReader.current;
          }

          streams.writeConnectionPreface();
          expect(await nextFrame(), isA<SettingsFrame>());
          streams.writeRawFrame(
            type: FrameType.SETTINGS,
            flags: SettingsFrame.FLAG_ACK,
            streamId: 0,
            payload: const [],
          );
          streams.writeRawFrame(
            type: FrameType.SETTINGS,
            flags: 0,
            streamId: 0,
            payload: const [],
          );
          expect(await nextFrame(), isA<SettingsFrame>());

          final payload = switch (frameType) {
            FrameType.SETTINGS => const <int>[],
            FrameType.PING => const <int>[0, 0, 0, 0, 0, 0, 0, 1],
            FrameType.GOAWAY => const <int>[0, 0, 0, 0, 0, 0, 0, 0],
            _ => const <int>[],
          };
          streams.writeRawFrame(
            type: frameType,
            flags: 0,
            streamId: 1,
            payload: payload,
          );

          expect(
            await nextFrame(),
            isA<GoawayFrame>().having(
              (f) => f.errorCode,
              'errorCode',
              ErrorCode.PROTOCOL_ERROR,
            ),
          );
          expect(await clientReader.moveNext(), isFalse);
          expect(await incoming, isEmpty);
        }
      });
    });

    group('server-errors', () {
      serverTest('server-resets-stream', (
        ServerTransportConnection server,
        FrameWriter clientWriter,
        StreamIterator<Frame> clientReader,
        Future<Frame> Function() nextFrame,
      ) async {
        Future serverFun() async {
          var it = StreamIterator(server.incomingStreams);
          expect(await it.moveNext(), true);

          TransportStream stream = it.current;
          stream.terminate();

          expect(await it.moveNext(), false);

          await server.finish();
        }

        Future clientFun() async {
          expect(await nextFrame() is SettingsFrame, true);
          clientWriter.writeSettingsAckFrame();
          clientWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);

          clientWriter.writeHeadersFrame(1, [
            Header.ascii('a', 'b'),
          ], endStream: false);

          // Make sure the client gets a [RstStreamFrame] frame.
          expect(
            await nextFrame(),
            isA<RstStreamFrame>()
                .having((f) => f.errorCode, 'errorCode', ErrorCode.CANCEL)
                .having((f) => f.header.streamId, 'header.streamId', 1),
          );

          // Tell the server to finish.
          clientWriter.writeGoawayFrame(3, ErrorCode.NO_ERROR, []);

          // Make sure the server ended the connection.
          expect(await clientReader.moveNext(), false);
        }

        await Future.wait([serverFun(), clientFun()]);
      });
    });

    group('max-concurrent-streams', () {
      test('exceeding-max-concurrent-streams', () async {
        var writeA = StreamController<List<int>>();
        var writeB = StreamController<List<int>>();

        var server = ServerTransportConnection.viaStreams(
          writeB.stream,
          writeA,
          settings: const ServerSettings(concurrentStreamLimit: 2),
        );

        var localSettings = ActiveSettings();
        var clientReader = StreamIterator(
          FrameReader(writeA.stream, localSettings).startDecoding(),
        );

        Future<Frame> nextFrame() async {
          expect(await clientReader.moveNext(), true);
          return clientReader.current;
        }

        var encoder = HPackEncoder();
        var peerSettings = ActiveSettings();
        writeB.add(CONNECTION_PREFACE);
        var clientWriter = FrameWriter(encoder, writeB, peerSettings);

        var clientDone = Completer<void>();

        Future serverFun() async {
          var incoming = <ServerTransportStream>[];
          var subscription = server.incomingStreams.listen(incoming.add);

          await clientDone.future;

          expect(incoming.length, 2);
          await subscription.cancel();
          await server.terminate();
        }

        Future clientFun() async {
          expect(await nextFrame() is SettingsFrame, true);
          clientWriter.writeSettingsAckFrame();
          clientWriter.writeSettingsFrame([]);
          expect(await nextFrame() is SettingsFrame, true);

          clientWriter.writeHeadersFrame(1, [
            Header.ascii('a', 'b'),
          ], endStream: false);
          clientWriter.writeHeadersFrame(3, [
            Header.ascii('a', 'b'),
          ], endStream: false);
          clientWriter.writeHeadersFrame(5, [
            Header.ascii('a', 'b'),
          ], endStream: false);

          var frame = await nextFrame();
          expect(
            frame,
            isA<RstStreamFrame>()
                .having(
                  (f) => f.errorCode,
                  'errorCode',
                  ErrorCode.REFUSED_STREAM,
                )
                .having((f) => f.header.streamId, 'header.streamId', 5),
          );

          clientDone.complete();

          var hasGoaway = await clientReader.moveNext();
          expect(hasGoaway, true);
          expect(clientReader.current is GoawayFrame, true);

          var closed = await clientReader.moveNext();
          expect(closed, false);
        }

        await [serverFun(), clientFun()].wait;
      });
    });
  });
}

/// Lets [flood] write frames to the server while the client reads nothing,
/// and expects the server to terminate the connection with
/// `ENHANCE_YOUR_CALM` rather than queue its replies without limit.
///
/// Returns the frames the server had queued, which are still delivered.
Future<List<Frame>> expectTerminatedWhileNotReading(
  ServerTransportConnection server,
  FrameWriter clientWriter,
  StreamIterator<Frame> clientReader,
  Future<Frame> Function() nextFrame,
  void Function() flood,
) async {
  expect(await nextFrame(), isA<SettingsFrame>());
  clientWriter.writeSettingsAckFrame();
  clientWriter.writeSettingsFrame([]);
  expect(await nextFrame(), isA<SettingsFrame>());

  // An open stream reports the error the connection is terminated with.
  final streams = StreamIterator(server.incomingStreams);
  clientWriter.writeHeadersFrame(1, [Header.ascii('a', 'b')], endStream: false);
  expect(await streams.moveNext(), isTrue);
  Object? error;
  streams.current.incomingMessages.listen(
    null,
    onError: (Object e) => error = e,
  );

  // The client does not call `nextFrame()` until the server is done, so the
  // server's frames cannot be written.
  flood();
  await pumpEventQueue();
  expect(
    error,
    isA<TransportConnectionException>().having(
      (e) => e.errorCode,
      'errorCode',
      ErrorCode.ENHANCE_YOUR_CALM,
    ),
  );

  final queued = <Frame>[];
  while (await clientReader.moveNext()) {
    queued.add(clientReader.current);
  }
  return queued;
}

void serverTest(
  String name,
  void Function(
    ServerTransportConnection,
    FrameWriter,
    StreamIterator<Frame> frameReader,
    Future<Frame> Function() readNext,
  )
  func, {
  ServerSettings? serverSettings,
}) {
  return test(name, () {
    var streams = ClientErrorStreams(serverSettings);
    var clientReader = streams.clientConnectionFrameReader;

    Future<Frame> readNext() async {
      expect(await clientReader.moveNext(), true);
      return clientReader.current;
    }

    return func(
      streams.serverConnection,
      streams.clientConnectionFrameWriter,
      clientReader,
      readNext,
    );
  });
}

class ClientErrorStreams {
  final ServerSettings? serverSettings;
  final StreamController<List<int>> writeA = StreamController();
  final StreamController<List<int>> writeB = StreamController();
  Stream<List<int>> get readA => writeA.stream;
  Stream<List<int>> get readB => writeB.stream;

  ClientErrorStreams([this.serverSettings]);

  void writeConnectionPreface() {
    writeB.add(CONNECTION_PREFACE);
  }

  void writeRawFrame({
    required int type,
    required int flags,
    required int streamId,
    required List<int> payload,
  }) {
    final length = payload.length;
    writeB.add([
      (length >> 16) & 0xff,
      (length >> 8) & 0xff,
      length & 0xff,
      type,
      flags,
      (streamId >> 24) & 0x7f,
      (streamId >> 16) & 0xff,
      (streamId >> 8) & 0xff,
      streamId & 0xff,
      ...payload,
    ]);
  }

  void writeRawFrameHeader({
    required int length,
    required int type,
    required int flags,
    required int streamId,
  }) {
    writeB.add([
      (length >> 16) & 0xff,
      (length >> 8) & 0xff,
      length & 0xff,
      type,
      flags,
      (streamId >> 24) & 0x7f,
      (streamId >> 16) & 0xff,
      (streamId >> 8) & 0xff,
      streamId & 0xff,
    ]);
  }

  StreamIterator<Frame> get clientConnectionFrameReader {
    var localSettings = ActiveSettings();
    return StreamIterator(FrameReader(readA, localSettings).startDecoding());
  }

  FrameWriter get clientConnectionFrameWriter {
    var encoder = HPackEncoder();
    var peerSettings = ActiveSettings();
    writeB.add(CONNECTION_PREFACE);
    return FrameWriter(encoder, writeB, peerSettings);
  }

  ServerTransportConnection get serverConnection =>
      ServerTransportConnection.viaStreams(
        readB,
        writeA,
        settings: serverSettings,
      );
}
