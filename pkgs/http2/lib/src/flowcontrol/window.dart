// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class Window {
  static const int MAX_WINDOW_SIZE = (1 << 31) - 1;

  /// The size available in this window.
  ///
  /// The default flow control window for the entire connection and for new
  /// streams is 65535).
  ///
  /// NOTE: This value can potentially become negative.
  int _size;

  Window({int initialSize = (1 << 16) - 1}) : _size = initialSize;

  /// The current size of the flow control window.
  int get size => _size;

  void modify(int difference) {
    _size += difference;
  }
}
