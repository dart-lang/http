// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:http2/src/connection_preface.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/hpack/hpack.dart';
import 'package:http2/src/settings/settings.dart';
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
