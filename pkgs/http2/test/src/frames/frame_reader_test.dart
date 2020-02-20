// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/settings/settings.dart';

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
        dataFrame(body).listen(expectAsync1((Frame frame) {
          expect(frame, isA<DataFrame>());
          expect(frame.header, hasLength(body.length));
          expect(frame.header.flags, 0);
          var dataFrame = frame as DataFrame;
          expect(dataFrame.hasEndStreamFlag, isFalse);
          expect(dataFrame.hasPaddedFlag, isFalse);
          expect(dataFrame.bytes, body);
        }), onError: expectAsync2((error, stack) {}, count: 0));
      });

      test('data-frame--max-frame-size-plus-1', () {
        var body = List.filled(maxFrameSize + 1, 0x42);
        dataFrame(body).listen(expectAsync1((_) {}, count: 0),
            onError: expectAsync2((error, stack) {
          expect('$error', contains('Incoming frame is too big'));
        }));
      });

      test('incomplete-header', () {
        var settings = ActiveSettings();

        var controller = StreamController<List<int>>();
        var reader = FrameReader(controller.stream, settings);

        controller
          ..add([1])
          ..close();

        reader.startDecoding().listen(expectAsync1((_) {}, count: 0),
            onError: expectAsync2((error, stack) {
          expect('$error', contains('incomplete frame'));
        }));
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

        reader.startDecoding().listen(expectAsync1((_) {}, count: 0),
            onError: expectAsync2((error, stack) {
          expect('$error', contains('incomplete frame'));
        }));
      });

      test('connection-error', () {
        var settings = ActiveSettings();

        var controller = StreamController<List<int>>();
        var reader = FrameReader(controller.stream, settings);

        controller
          ..addError('hello world')
          ..close();

        reader.startDecoding().listen(expectAsync1((_) {}, count: 0),
            onError: expectAsync2((error, stack) {
          expect('$error', contains('hello world'));
        }));
      });
    });
  });
}
