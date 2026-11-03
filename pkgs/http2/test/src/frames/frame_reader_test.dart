// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/settings/settings.dart';
import 'package:test/test.dart';

void main() {
  group('frames', () {
    group('frame-reader', () {
      final maxFrameSize = ActiveSettings().maxFrameSize;

      Stream<Frame> dataFrame(List<int> body) {
        var settings = ActiveSettings();
        var controller = StreamController<List<int>>();
        var reader = FrameReader(controller.stream, settings);

        // This is a DataFrame:
        //   - length: n
        //   - type: [0]
        //   - flags: [0]
        //   - stream id: [0, 0, 0, 1]
        controller
          ..add([0, (body.length >> 8) & 0xff, body.length & 0xff])
          ..add([0])
          ..add([0])
          ..add([0, 0, 0, 1])
          ..add(body)
          ..close();
        return reader.startDecoding();
      }

      test('data-frame--max-frame-size', () {
        var body = List.filled(maxFrameSize, 0x42);
        dataFrame(body).listen(
          expectAsync1((Frame frame) {
            expect(frame, isA<DataFrame>());
            expect(frame.header, hasLength(body.length));
            expect(frame.header.flags, 0);
            var dataFrame = frame as DataFrame;
            expect(dataFrame.hasEndStreamFlag, isFalse);
            expect(dataFrame.hasPaddedFlag, isFalse);
            expect(dataFrame.bytes, body);
          }),
          onError: expectAsync2((Object error, StackTrace stack) {}, count: 0),
        );
      });

      test('data-frame--max-frame-size-plus-1', () {
        var body = List.filled(maxFrameSize + 1, 0x42);
        dataFrame(body).listen(
          expectAsync1((_) {}, count: 0),
          onError: expectAsync2((Object error, StackTrace stack) {
            expect('$error', contains('Incoming frame is too big'));
          }),
        );
      });

      test('incomplete-header', () {
        var settings = ActiveSettings();

        var controller = StreamController<List<int>>();
        var reader = FrameReader(controller.stream, settings);

        controller
          ..add([1])
          ..close();

        reader.startDecoding().listen(
          expectAsync1((_) {}, count: 0),
          onError: expectAsync2((Object error, StackTrace stack) {
            expect('$error', contains('incomplete frame'));
          }),
        );
      });

      test('incomplete-frame', () {
        var settings = ActiveSettings();

        var controller = StreamController<List<int>>();
        var reader = FrameReader(controller.stream, settings);

        // This is a DataFrame:
        //   - length: [0, 0, 255]
        //   - type: [0]
        //   - flags: [0]
        //   - stream id: [0, 0, 0, 1]
        controller
          ..add([0, 0, 255, 0, 0, 0, 0, 0, 1])
          ..close();

        reader.startDecoding().listen(
          expectAsync1((_) {}, count: 0),
          onError: expectAsync2((Object error, StackTrace stack) {
            expect('$error', contains('incomplete frame'));
          }),
        );
      });

      test('connection-error', () {
        var settings = ActiveSettings();

        var controller = StreamController<List<int>>();
        var reader = FrameReader(controller.stream, settings);

        controller
          ..addError('hello world')
          ..close();

        reader.startDecoding().listen(
          expectAsync1((_) {}, count: 0),
          onError: expectAsync2((Object error, StackTrace stack) {
            expect('$error', contains('hello world'));
          }),
        );
      });

      group('field-block-callbacks', () {
        // A field block fragment (:method GET, :scheme http, :path /).
        const fragment = [0x82, 0x86, 0x84];
        final headers = _frame(
          FrameType.HEADERS,
          HeadersFrame.FLAG_END_HEADERS,
          fragment,
        );
        final headersWithoutEnd = _frame(FrameType.HEADERS, 0, fragment);
        final continuation = _frame(FrameType.CONTINUATION, 0, fragment);
        final lastContinuation = _frame(
          FrameType.CONTINUATION,
          ContinuationFrame.FLAG_END_HEADERS,
          fragment,
        );
        final pushPromise = _frame(
          FrameType.PUSH_PROMISE,
          PushPromiseFrame.FLAG_END_HEADERS,
          [0, 0, 0, 2, ...fragment],
        );
        final data = _frame(FrameType.DATA, 0, List.filled(100, 0x42));

        test('field-blocks-within-one-chunk-are-never-incomplete', () async {
          final reader = _FieldBlockRecorder();

          // E.g. a gRPC response: HEADERS, DATA and trailers in one chunk.
          await reader.receive([...headers, ...data, ...headers]);
          expect(reader.frames, [
            isA<HeadersFrame>(),
            isA<DataFrame>(),
            isA<HeadersFrame>(),
          ]);
          expect(reader.callbacks, ['end', 'end']);

          await reader.receive([
            ...headersWithoutEnd,
            ...continuation,
            ...lastContinuation,
            ...pushPromise,
          ]);
          expect(reader.frames, hasLength(7));
          expect(reader.callbacks, ['end', 'end', 'end', 'end']);
        });

        test('a-frame-split-outside-a-field-block-is-not-incomplete', () async {
          final reader = _FieldBlockRecorder();

          await reader.receive([...headers, ...data.sublist(0, 20)]);
          expect(reader.frames, [isA<HeadersFrame>()]);
          expect(reader.callbacks, ['end']);

          await reader.receive(data.sublist(20));
          expect(reader.frames, [isA<HeadersFrame>(), isA<DataFrame>()]);
          expect(reader.callbacks, ['end']);
        });

        test('headers-payload-split-across-chunks-is-incomplete', () async {
          final reader = _FieldBlockRecorder();
          const split = FRAME_HEADER_SIZE + 1;

          await reader.receive([...data, ...headers.sublist(0, split)]);
          expect(reader.frames, [isA<DataFrame>()]);
          expect(reader.callbacks, ['incomplete']);

          await reader.receive(headers.sublist(split));
          expect(reader.frames, [isA<DataFrame>(), isA<HeadersFrame>()]);
          expect(reader.callbacks, ['incomplete', 'end']);
        });

        test('push-promise-header-without-payload-is-incomplete', () async {
          final reader = _FieldBlockRecorder();

          await reader.receive(pushPromise.sublist(0, FRAME_HEADER_SIZE));
          expect(reader.frames, isEmpty);
          expect(reader.callbacks, ['incomplete']);

          await reader.receive(pushPromise.sublist(FRAME_HEADER_SIZE));
          expect(reader.frames, [isA<PushPromiseFrame>()]);
          expect(reader.callbacks, ['incomplete', 'end']);
        });

        test('headers-waiting-for-continuation-is-incomplete', () async {
          final reader = _FieldBlockRecorder();

          await reader.receive(headersWithoutEnd);
          expect(reader.frames, [isA<HeadersFrame>()]);
          expect(reader.callbacks, ['incomplete']);

          // Reported again for every chunk that leaves the block incomplete,
          // also one that ends inside a CONTINUATION frame.
          await reader.receive([...continuation, ...lastContinuation.take(5)]);
          expect(reader.frames, hasLength(2));
          expect(reader.callbacks, ['incomplete', 'incomplete']);

          await reader.receive([...lastContinuation.skip(5), ...headers]);
          expect(reader.frames, [
            isA<HeadersFrame>(),
            isA<ContinuationFrame>(),
            isA<ContinuationFrame>(),
            isA<HeadersFrame>(),
          ]);
          expect(reader.callbacks, ['incomplete', 'incomplete', 'end', 'end']);
        });
      });
    });
  });
}

/// The bytes of a frame of [type] on stream 1.
List<int> _frame(int type, int flags, List<int> payload) => [
  (payload.length >> 16) & 0xff,
  (payload.length >> 8) & 0xff,
  payload.length & 0xff,
  type,
  flags,
  0,
  0,
  0,
  1,
  ...payload,
];

/// Feeds chunks of bytes to a [FrameReader] and records the frames it
/// decodes, as well as its field-block callbacks in the order of the calls.
class _FieldBlockRecorder {
  final _input = StreamController<List<int>>();
  final frames = <Frame>[];
  final callbacks = <String>[];

  _FieldBlockRecorder() {
    FrameReader(
      _input.stream,
      ActiveSettings(),
      onFieldBlockIncomplete: () => callbacks.add('incomplete'),
      onFieldBlockEnd: () => callbacks.add('end'),
    ).startDecoding().listen(frames.add);
    addTearDown(_input.close);
  }

  /// Delivers [chunk] as one read from the socket and waits for the reader to
  /// process it.
  Future<void> receive(List<int> chunk) async {
    _input.add(chunk);
    await pumpEventQueue();
  }
}
