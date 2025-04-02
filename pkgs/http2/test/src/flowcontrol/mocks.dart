// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:http2/src/flowcontrol/connection_queues.dart';
import 'package:http2/src/flowcontrol/stream_queues.dart';
import 'package:http2/src/flowcontrol/window_handler.dart';
import 'package:http2/src/frames/frames.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks(
  [FrameWriter, IncomingWindowHandler, OutgoingStreamWindowHandler],
  customMocks: [
    MockSpec<ConnectionMessageQueueOut>(
      fallbackGenerators: {
        #ensureNotTerminatedSync: ensureNotTerminatedSyncFallback,
      },
    ),
    MockSpec<StreamMessageQueueIn>(
      fallbackGenerators: {
        #ensureNotTerminatedSync: ensureNotTerminatedSyncFallback,
      },
    ),
  ],
)
T ensureNotTerminatedSyncFallback<T>(T Function()? f) =>
    throw UnimplementedError(
      'Method cannot be stubbed; requires fallback values for return',
    );
