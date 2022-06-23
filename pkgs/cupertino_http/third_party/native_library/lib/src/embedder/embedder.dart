// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'embedder_standalone.dart' if (dart.library.ui) "embedder_flutter.dart"
    as embedder;

/// Whether the embedder is Flutter.
bool get isFlutter => embedder.isFlutter;

/// Whether the embedder is Dart standalone.
bool get isStandalone => embedder.isStandalone;
