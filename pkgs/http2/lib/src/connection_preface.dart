// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'byte_utils.dart';

/// This is a set of bytes with which a client connection begins in the normal
/// case. It can be used on a server to distinguish HTTP/1.1 and HTTP/2 clients.
const List<int> CONNECTION_PREFACE = [
  0x50,
  0x52,
  0x49,
  0x20,
  0x2a,
  0x20,
  0x48,
  0x54,
  0x54,
  0x50,
  0x2f,
  0x32,
  0x2e,
  0x30,
  0x0d,
  0x0a,
  0x0d,
  0x0a,
  0x53,
  0x4d,
  0x0d,
  0x0a,
  0x0d,
  0x0a
];

/// Reads the connection preface from [incoming].
///
/// The returned `Stream` will be a duplicate of `incoming` without the
/// connection preface. If an error occurs while reading the connection
/// preface, the returned stream will have only an error.
Stream<List<int>> readConnectionPreface(Stream<List<int>> incoming) {
  StreamController<List<int>> result;
  StreamSubscription subscription;
  var connectionPrefaceRead = false;
  var prefaceBuffer = <int>[];
  var terminated = false;

  void terminate(error) {
    if (!terminated) {
      result.addError(error);
      result.close();
      subscription.cancel();
    }
    terminated = true;
  }

  bool compareConnectionPreface(List<int> data) {
    for (var i = 0; i < CONNECTION_PREFACE.length; i++) {
      if (data[i] != CONNECTION_PREFACE[i]) {
        terminate('Connection preface does not match.');
        return false;
      }
    }
    prefaceBuffer = null;
    connectionPrefaceRead = true;
    return true;
  }

  void onData(List<int> data) {
    if (connectionPrefaceRead) {
      // Forward data after reading preface.
      result.add(data);
    } else {
      if (prefaceBuffer.isEmpty && data.length > CONNECTION_PREFACE.length) {
        if (!compareConnectionPreface(data)) return;
        data = data.sublist(CONNECTION_PREFACE.length);
      } else if (prefaceBuffer.length < CONNECTION_PREFACE.length) {
        var remaining = CONNECTION_PREFACE.length - prefaceBuffer.length;

        var end = min(data.length, remaining);
        var part1 = viewOrSublist(data, 0, end);
        var part2 = viewOrSublist(data, end, data.length - end);
        prefaceBuffer.addAll(part1);

        if (prefaceBuffer.length == CONNECTION_PREFACE.length) {
          if (!compareConnectionPreface(prefaceBuffer)) return;
        }
        data = part2;
      }
      if (data.isNotEmpty) {
        result.add(data);
      }
    }
  }

  result = StreamController(
      onListen: () {
        subscription = incoming.listen(onData,
            onError: (e, StackTrace s) => result.addError(e, s),
            onDone: () {
              if (prefaceBuffer != null) {
                terminate('EOS before connection preface could be read.');
              } else {
                result.close();
              }
            });
      },
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
      onCancel: () => subscription.cancel());

  return result.stream;
}
