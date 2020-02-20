// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/frames/frame_defragmenter.dart';

import '../error_matchers.dart';

void main() {
  group('frames', () {
    group('frame-defragmenter', () {
      UnknownFrame unknownFrame() {
        return UnknownFrame(FrameHeader(0, 0, 0, 1), []);
      }

      HeadersFrame headersFrame(List<int> data,
          {bool fragmented = false, int streamId = 1}) {
        var flags = fragmented ? 0 : HeadersFrame.FLAG_END_HEADERS;
        var header =
            FrameHeader(data.length, FrameType.HEADERS, flags, streamId);
        return HeadersFrame(header, 0, false, null, null, data);
      }

      PushPromiseFrame pushPromiseFrame(List<int> data,
          {bool fragmented = false, int streamId = 1}) {
        var flags = fragmented ? 0 : HeadersFrame.FLAG_END_HEADERS;
        var header =
            FrameHeader(data.length, FrameType.PUSH_PROMISE, flags, streamId);
        return PushPromiseFrame(header, 0, 44, data);
      }

      ContinuationFrame continuationFrame(List<int> data,
          {bool fragmented = false, int streamId = 1}) {
        var flags = fragmented ? 0 : ContinuationFrame.FLAG_END_HEADERS;
        var header =
            FrameHeader(data.length, FrameType.CONTINUATION, flags, streamId);
        return ContinuationFrame(header, data);
      }

      test('unknown-frame', () {
        var defrag = FrameDefragmenter();
        expect(defrag.tryDefragmentFrame(unknownFrame()) is UnknownFrame, true);
      });

      test('fragmented-headers-frame', () {
        var defrag = FrameDefragmenter();

        var f1 = headersFrame([1, 2, 3], fragmented: true);
        var f2 = continuationFrame([4, 5, 6], fragmented: true);
        var f3 = continuationFrame([7, 8, 9], fragmented: false);

        expect(defrag.tryDefragmentFrame(f1), isNull);
        expect(defrag.tryDefragmentFrame(f2), isNull);
        var h = defrag.tryDefragmentFrame(f3) as HeadersFrame;
        expect(h.hasEndHeadersFlag, isTrue);
        expect(h.hasEndStreamFlag, isFalse);
        expect(h.hasPaddedFlag, isFalse);
        expect(h.padLength, 0);
        expect(h.headerBlockFragment, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
      });

      test('fragmented-push-promise-frame', () {
        var defrag = FrameDefragmenter();

        var f1 = pushPromiseFrame([1, 2, 3], fragmented: true);
        var f2 = continuationFrame([4, 5, 6], fragmented: true);
        var f3 = continuationFrame([7, 8, 9], fragmented: false);

        expect(defrag.tryDefragmentFrame(f1), isNull);
        expect(defrag.tryDefragmentFrame(f2), isNull);
        var h = defrag.tryDefragmentFrame(f3) as PushPromiseFrame;
        expect(h.hasEndHeadersFlag, isTrue);
        expect(h.hasPaddedFlag, isFalse);
        expect(h.padLength, 0);
        expect(h.headerBlockFragment, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
      });

      test('fragmented-headers-frame--wrong-id', () {
        var defrag = FrameDefragmenter();

        var f1 = headersFrame([1, 2, 3], fragmented: true, streamId: 1);
        var f2 = continuationFrame([4, 5, 6], fragmented: true, streamId: 2);

        expect(defrag.tryDefragmentFrame(f1), isNull);
        expect(
            () => defrag.tryDefragmentFrame(f2), throwsA(isProtocolException));
      });

      test('fragmented-push-promise-frame', () {
        var defrag = FrameDefragmenter();

        var f1 = pushPromiseFrame([1, 2, 3], fragmented: true, streamId: 1);
        var f2 = continuationFrame([4, 5, 6], fragmented: true, streamId: 2);

        expect(defrag.tryDefragmentFrame(f1), isNull);
        expect(
            () => defrag.tryDefragmentFrame(f2), throwsA(isProtocolException));
      });

      test('fragmented-headers-frame--no-continuation-frame', () {
        var defrag = FrameDefragmenter();

        var f1 = headersFrame([1, 2, 3], fragmented: true);
        var f2 = unknownFrame();

        expect(defrag.tryDefragmentFrame(f1), isNull);
        expect(
            () => defrag.tryDefragmentFrame(f2), throwsA(isProtocolException));
      });

      test('fragmented-push-promise-no-continuation-frame', () {
        var defrag = FrameDefragmenter();

        var f1 = pushPromiseFrame([1, 2, 3], fragmented: true);
        var f2 = unknownFrame();

        expect(defrag.tryDefragmentFrame(f1), isNull);
        expect(
            () => defrag.tryDefragmentFrame(f2), throwsA(isProtocolException));
      });

      test('push-without-headres-or-push-promise-frame', () {
        var defrag = FrameDefragmenter();

        var f1 = continuationFrame([4, 5, 6], fragmented: true, streamId: 1);
        expect(defrag.tryDefragmentFrame(f1), equals(f1));
      });
    });
  });
}
