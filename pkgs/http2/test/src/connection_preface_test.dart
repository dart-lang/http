// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math' show min;

import 'package:http2/src/connection_preface.dart';
import 'package:pedantic/pedantic.dart';
import 'package:test/test.dart';

void main() {
  group('connection-preface', () {
    test('successful', () async {
      final frameBytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      final data = List<int>.from(CONNECTION_PREFACE)..addAll(frameBytes);

      for (var size = 1; size <= data.length; size++) {
        var c = StreamController<List<int>>();
        var resultF =
            readConnectionPreface(c.stream).fold([], (b, d) => b..addAll(d));

        for (var i = 0; i < (size - 1 + data.length) ~/ size; i++) {
          var from = size * i;
          var to = min(size * (i + 1), data.length);

          c.add(data.sublist(from, to));
        }
        unawaited(c.close());

        expect(await resultF, frameBytes);
      }
    });

    test('only-part-of-connection-sequence', () async {
      var c = StreamController<List<int>>();
      var resultF =
          readConnectionPreface(c.stream).fold([], (b, d) => b..addAll(d));

      for (var i = 0; i < CONNECTION_PREFACE.length - 1; i++) {
        c.add([CONNECTION_PREFACE[i]]);
      }
      unawaited(c.close());

      unawaited(resultF.catchError(expectAsync2((error, _) {
        expect(error, contains('EOS before connection preface could be read'));
      })));
    });

    test('wrong-connection-sequence', () async {
      var c = StreamController<List<int>>();
      var resultF =
          readConnectionPreface(c.stream).fold([], (b, d) => b..addAll(d));

      for (var i = 0; i < CONNECTION_PREFACE.length; i++) {
        c.add([0xff]);
      }
      unawaited(c.close());

      unawaited(resultF.catchError(expectAsync2((error, _) {
        expect(error, contains('Connection preface does not match.'));
      })));
    });

    test('incoming-socket-error', () async {
      var c = StreamController<List<int>>();
      var resultF =
          readConnectionPreface(c.stream).fold([], (b, d) => b..addAll(d));

      c.addError('hello world');
      unawaited(c.close());

      unawaited(resultF.catchError(expectAsync2((error, _) {
        expect(error, contains('hello world'));
      })));
    });
  });
}
