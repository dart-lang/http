// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import 'package:http2/src/hpack/hpack.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:http2/src/settings/settings.dart';

void main() {
  group('frames', () {
    group('frame-writer', () {
      test('connection-error', () {
        var settings = ActiveSettings();
        var context = HPackContext();
        var controller = StreamController<List<int>>();
        var writer = FrameWriter(context.encoder, controller, settings);

        writer.doneFuture.then(expectAsync1((_) {
          // We expect that the writer is done at this point.
        }));

        // We cancel here the reading part (simulates a dying socket).
        controller.stream.listen((_) {}).cancel();
      });
    });
  });
}
