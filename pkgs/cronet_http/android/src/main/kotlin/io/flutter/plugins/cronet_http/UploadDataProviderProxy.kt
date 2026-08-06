// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Cronet uploads request bodies by subclassing the abstract class
// `UploadDataProvider`. Cronet calls `getLength()`, then repeatedly calls
// `read()` to pull bytes into a `ByteBuffer`, and may call `rewind()` on
// redirects before calling `close()` when the upload finishes.
//
// `package:jnigen` does not support subclassing abstract Java classes from Dart
// (see https://github.com/dart-lang/jnigen/issues/348).
//
// This file provides an interface `UploadDataProviderInterface`, which can be
// implemented in Dart, and a wrapper class `UploadDataProviderProxy`, which
// can be passed to Cronet's `UrlRequest.Builder.setUploadDataProvider`.

package io.flutter.plugins.cronet_http

import androidx.annotation.Keep
import org.chromium.net.UploadDataProvider
import org.chromium.net.UploadDataSink
import java.nio.ByteBuffer

// Due to a bug (https://github.com/dart-lang/native/issues/2421) where JNIgen
// does not synchronize nullabilities across the class hierarchy and the fact
// that UploadDataProvider is a Java class with no nullability annotations,
// generating both `UploadDataProviderProxy` and `UploadDataProvider` together
// with different nullabilities causes the super method to have a looser type
// for parameters which is a Dart compilation error.
// That is why `read` and `rewind` parameters on the interface are defined as
// nullable to match `UploadDataProvider` while in reality Cronet always
// passes non-null values.

@Keep
class UploadDataProviderProxy(
    private val callback: UploadDataProviderInterface
) : UploadDataProvider() {

    @Keep
    interface UploadDataProviderInterface {
        fun getLength(): Long
        fun read(uploadDataSink: UploadDataSink?, byteBuffer: ByteBuffer?)
        fun rewind(uploadDataSink: UploadDataSink?)
        fun close()
    }

    override fun getLength(): Long = callback.getLength()

    override fun read(uploadDataSink: UploadDataSink, byteBuffer: ByteBuffer) =
        callback.read(uploadDataSink, byteBuffer)

    override fun rewind(uploadDataSink: UploadDataSink) =
        callback.rewind(uploadDataSink)

    override fun close() = callback.close()
}
