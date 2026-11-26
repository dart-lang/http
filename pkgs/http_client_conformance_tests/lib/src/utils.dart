// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';
import 'dart:typed_data';

const _templateSize = 1024 * 1024;
const _maxUint32Exclusive = 0x100000000; // 2^32

final _random = Random();

/// Random (and therefore incompressible) bytes. Generated once because it is
/// slow.
final _randomBytes = () {
  final bytes = Uint8List(_templateSize);
  final data = ByteData.sublistView(bytes);
  for (var offset = 0; offset < bytes.length; offset += 4) {
    data.setUint32(offset, _random.nextInt(_maxUint32Exclusive));
  }
  return bytes;
}();

/// Creates a [length]-byte incompressible test payload.
///
/// Mutates a 32-bit random integer on every 4 KB page so OS zero-page
/// deduplication, same-page deduplication, and memory compression cannot hide
/// leaked buffers from RSS checks.
Uint8List createTestPayload(int length) {
  final payload = Uint8List(length);
  for (var offset = 0; offset < length; offset += _randomBytes.length) {
    final end = min(offset + _randomBytes.length, length);
    payload.setRange(offset, end, _randomBytes);
  }
  final data = ByteData.sublistView(payload);
  for (var offset = 0; offset + 4 <= length; offset += 4096) {
    data.setUint32(offset, _random.nextInt(_maxUint32Exclusive));
  }
  return payload;
}
