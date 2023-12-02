// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:async/async.dart';

extension StreamQueueOfNullableObjectExtension on StreamQueue<Object?> {
  /// When run under dart2wasm, JSON numbers are always returned as [double].
  Future<int> get nextAsInt async => ((await next) as num).toInt();
}
