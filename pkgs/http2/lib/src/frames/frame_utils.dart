// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of http2.src.frames;

int _readInt64(List<int> bytes, int offset) {
  int high = _readInt32(bytes, offset);
  int low = _readInt32(bytes, offset + 4);
  return high << 32 | low;
}

int _readInt32(List<int> bytes, int offset) {
  return (bytes[offset] << 24) | (bytes[offset + 1] << 16) |
         (bytes[offset + 2] << 8) | bytes[offset + 3];
}

int _readInt24(List<int> bytes, int offset) {
  return (bytes[offset] << 16) | (bytes[offset + 1] << 8) | bytes[offset + 2];
}

int _readInt16(List<int> bytes, int offset) {
  return (bytes[offset] << 8) | bytes[offset + 1];
}


void _writeInt64(List<int> bytes, int offset, int value) {
  _writeInt32(bytes, offset, value >> 32);
  _writeInt32(bytes, offset + 4, value & 0xffffffff);
}

void _writeInt32(List<int> bytes, int offset, int value) {
  bytes[offset] = (value >> 24) & 0xff;
  bytes[offset + 1] = (value >> 16) & 0xff;
  bytes[offset + 2] = (value >> 8) & 0xff;
  bytes[offset + 3] = value & 0xff;
}

void _writeInt24(List<int> bytes, int offset, int value) {
  bytes[offset] = (value >> 16) & 0xff;
  bytes[offset + 1] = (value >> 8) & 0xff;
  bytes[offset + 2] = value & 0xff;
}

void _writeInt16(List<int> bytes, int offset, int value) {
  bytes[offset] = (value >> 8) & 0xff;
  bytes[offset + 1] = value & 0xff;
}

bool _isFlagSet(int value, int bit) => value & bit == bit;
