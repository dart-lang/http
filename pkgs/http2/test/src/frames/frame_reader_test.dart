// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import 'package:http2/src/hpack/hpack.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/settings/settings.dart';

import '../hpack/hpack_test.dart' show isHeader;

main() {
  group('frames', () {
    group('frame-reader', () {
      final int maxFrameSize = new Settings().maxFrameSize;

      Stream<Frame> dataFrame(List<int> body) {
        var settings = new Settings();
        var context = new HPackContext();
        var controller = new StreamController<List<int>>();
        var reader = new FrameReader(controller.stream, settings);

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
        var body = new List.filled(maxFrameSize, 0x42);
        dataFrame(body).listen(
            expectAsync((Frame frame) {
              expect(frame is DataFrame, isTrue);
              expect(frame.header.length, body.length);
              expect(frame.header.flags, 0);
              DataFrame dataFrame = frame;
              expect(dataFrame.hasEndStreamFlag, isFalse);
              expect(dataFrame.hasPaddedFlag, isFalse);
              expect(dataFrame.bytes, body);
            }),
            onError: expectAsync((error, stack) {}, count: 0));
      });

      test('data-frame--max-frame-size-plus-1', () {
        var body = new List.filled(maxFrameSize + 1, 0x42);
        dataFrame(body).listen(
            expectAsync((_) {}, count: 0),
            onError: expectAsync((error, stack) {
          expect('$error', contains('Incoming frame is too big'));
        }));
      });

      test('incomplete-header', () {
        var settings = new Settings();

        var context = new HPackContext();
        var controller = new StreamController<List<int>>();
        var reader = new FrameReader(controller.stream, settings);

        controller..add([1])..close();

        reader.startDecoding().listen(
            expectAsync((_) {}, count: 0),
            onError: expectAsync((error, stack) {
          expect('$error', contains('incomplete frame'));
        }));
      });

      test('incomplete-frame', () {
        var settings = new Settings();

        var context = new HPackContext();
        var controller = new StreamController<List<int>>();
        var reader = new FrameReader(controller.stream, settings);

        // This is a DataFrame:
        //   - length: [0, 0, 255]
        //   - type: [0]
        //   - flags: [0]
        //   - stream id: [0, 0, 0, 1]
        controller..add([0, 0, 255, 0, 0, 0, 0, 0, 1])..close();

        reader.startDecoding().listen(
            expectAsync((_) {}, count: 0),
            onError: expectAsync((error, stack) {
          expect('$error', contains('incomplete frame'));
        }));
      });

      test('connection-error', () {
        var settings = new Settings();

        var context = new HPackContext();
        var controller = new StreamController<List<int>>();
        var reader = new FrameReader(controller.stream, settings);

        controller..addError('hello world')..close();

        reader.startDecoding().listen(
            expectAsync((_) {}, count: 0),
            onError: expectAsync((error, stack) {
          expect('$error', contains('hello world'));
        }));
      });
    });
  });
}
