// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Cronet allows developers to manage HTTP requests by subclassing the
// the abstract class `UrlRequest.Callback`.
//
// `package:jnigen` does not support the ability to subclass abstract Java
// classes in Dart (see https://github.com/dart-lang/jnigen/issues/348).
//
// This file provides an interface `UrlRequestCallbackInterface`, which can
// be implemented in Dart and a wrapper class `UrlRequestCallbackProxy`, which
// can be passed to the Cronet API.

package io.flutter.plugins.cronet_http

import androidx.annotation.Keep
import org.chromium.net.CronetException
import org.chromium.net.UrlRequest
import org.chromium.net.UrlResponseInfo
import java.nio.ByteBuffer

// Due to a bug (https://github.com/dart-lang/native/issues/2421) where JNIgen
// does not synchronize the nullabilities across the class hierarchy and the
// fact that UrlRequest.Callback is a Java class with no nullability
// annotations, generating both `UrlRequestCallbackProxy` and
// `UrlRequest.Callback` together with different nullabilities causes the
// super method to have a looser type for parameters which is a Dart compilation
// error. 
// That is why all of the parameters of this class are defined as nullable to
// match `UrlRequest.Callback` while in reality only `onFailed`'s `info`
// parameter is nullable as specified in the cronet source code:
// https://source.chromium.org/chromium/chromium/src/+/main:components/cronet/android/api/src/org/chromium/net/UrlRequest.java;l=232

@Keep
class UrlRequestCallbackProxy(val callback: UrlRequestCallbackInterface) : UrlRequest.Callback() {
    @Keep
    interface UrlRequestCallbackInterface {
        fun onRedirectReceived(
            request: UrlRequest?,
            info: UrlResponseInfo?,
            newLocationUrl: String?
        )

        fun onResponseStarted(request: UrlRequest?, info: UrlResponseInfo?)

        fun onReadCompleted(
            request: UrlRequest?,
            info: UrlResponseInfo?,
            byteBuffer: ByteBuffer?
        )

        fun onSucceeded(request: UrlRequest?, info: UrlResponseInfo?)

        fun onCanceled(request: UrlRequest?, info: UrlResponseInfo?)

        fun onFailed(
            request: UrlRequest?,
            info: UrlResponseInfo?,
            error: CronetException?
        )
    }

    override fun onRedirectReceived(
        request: UrlRequest?,
        info: UrlResponseInfo?,
        newLocationUrl: String?
    ) {
        callback.onRedirectReceived(request, info, newLocationUrl);
    }

    override fun onResponseStarted(request: UrlRequest?, info: UrlResponseInfo?) {
        callback.onResponseStarted(request, info);
    }

    override fun onReadCompleted(
        request: UrlRequest?,
        info: UrlResponseInfo?,
        byteBuffer: ByteBuffer?
    ) {
        callback.onReadCompleted(request, info, byteBuffer);
    }

    override fun onSucceeded(request: UrlRequest?, info: UrlResponseInfo?) {
        callback.onSucceeded(request, info);
    }

    override fun onCanceled(request: UrlRequest?, info: UrlResponseInfo?) {
        callback.onCanceled(request, info);
    }

    override fun onFailed(
        request: UrlRequest?,
        info: UrlResponseInfo?,
        error: CronetException?
    ) {
        callback.onFailed(request, info, error);
    }
}
