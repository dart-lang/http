// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:http2/src/async_utils/async_utils.dart';
import 'package:test/test.dart';

void main() {
  group('async_utils', () {
    test('buffer-indicator', () {
      var bi = BufferIndicator();
      bi.bufferEmptyEvents.listen(expectAsync1((_) {}, count: 2));

      expect(bi.wouldBuffer, true);

      bi.markUnBuffered();
      expect(bi.wouldBuffer, false);

      bi.markBuffered();
      expect(bi.wouldBuffer, true);
      bi.markBuffered();
      expect(bi.wouldBuffer, true);

      bi.markUnBuffered();
      expect(bi.wouldBuffer, false);
      bi.markUnBuffered();
      expect(bi.wouldBuffer, false);

      bi.markBuffered();
      expect(bi.wouldBuffer, true);
      bi.markBuffered();
      expect(bi.wouldBuffer, true);
    });

    test('buffered-sink', () {
      var c = StreamController<List<int>>();
      var bs = BufferedSink(c);

      expect(bs.bufferIndicator.wouldBuffer, true);
      var sub = c.stream.listen(expectAsync1((_) {}, count: 2));

      expect(bs.bufferIndicator.wouldBuffer, false);

      sub.pause();
      Timer.run(
        expectAsync0(() {
          expect(bs.bufferIndicator.wouldBuffer, true);
          bs.sink.add([1]);

          sub.resume();
          Timer.run(
            expectAsync0(() {
              expect(bs.bufferIndicator.wouldBuffer, false);
              bs.sink.add([2]);

              Timer.run(
                expectAsync0(() {
                  sub.cancel();
                  expect(bs.bufferIndicator.wouldBuffer, false);
                }),
              );
            }),
          );
        }),
      );
    });

    test('buffered-sink-done-after-failed-write', () async {
      final bs = BufferedSink(FailingSink());
      bs.sink.add([1, 2, 3]);
      await bs.sink.close();
      // Must not hang on `FailingSink.done`, which (like `Socket.done` after a
      // failed `addStream`) never completes.
      await bs.doneFuture.timeout(const Duration(seconds: 2));
    });

    test('buffered-bytes-writer', () async {
      var c = StreamController<List<int>>();
      var writer = BufferedBytesWriter(c);

      expect(writer.bufferIndicator.wouldBuffer, true);

      var bytesFuture = c.stream.fold<List<int>>([], (b, d) => b..addAll(d));

      expect(writer.bufferIndicator.wouldBuffer, false);

      writer.add([1, 2]);
      writer.add([3, 4]);

      writer.addBufferedData([5, 6]);
      expect(() => writer.add([7, 8]), throwsStateError);

      writer.addBufferedData([7, 8]);
      await writer.close();
      expect(await bytesFuture, [1, 2, 3, 4, 5, 6, 7, 8]);
    });
  });
}

/// Behaves like a `dart:io` [Socket] whose peer has reset the connection:
/// [addStream] fails on the first write and [done] only ever completes through
/// an explicit [close], which `Stream.pipe` does not call after an error.
class FailingSink implements StreamSink<List<int>> {
  final _done = Completer<void>();

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final _ in stream) {
      throw const SocketException('Connection reset by peer');
    }
  }

  @override
  Future<void> close() {
    if (!_done.isCompleted) _done.complete();
    return _done.future;
  }

  @override
  Future<void> get done => _done.future;
}
