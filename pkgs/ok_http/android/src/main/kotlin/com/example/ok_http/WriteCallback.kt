// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

package com.example.ok_http

import java.io.IOException

/**
 * Callback interface utilized by [StreamingRequestBody].
 *
 * Signals to the Dart side when a chunk write has completed
 * or an error has occurred, enabling backpressure-aware streaming.
 */
interface WriteCallback {
    fun onWriteComplete()
    fun onError(e: IOException)
}
