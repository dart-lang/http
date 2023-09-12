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

import org.chromium.net.CronetException
import org.chromium.net.UrlRequest
import org.chromium.net.UrlResponseInfo
import java.nio.ByteBuffer


class UrlRequestCallbackProxy(val callback: UrlRequestCallbackInterface) : UrlRequest.Callback() {
    public interface UrlRequestCallbackInterface {
        fun onRedirectReceived(
            request: UrlRequest,
            info: UrlResponseInfo,
            newLocationUrl: String
        )

        fun onResponseStarted(request: UrlRequest?, info: UrlResponseInfo)
        fun onReadCompleted(
            request: UrlRequest,
            info: UrlResponseInfo,
            byteBuffer: ByteBuffer
        )

        fun onSucceeded(request: UrlRequest, info: UrlResponseInfo?)
        fun onFailed(
            request: UrlRequest,
            info: UrlResponseInfo?,
            error: CronetException
        )
    }

    override fun onRedirectReceived(
        request: UrlRequest,
        info: UrlResponseInfo,
        newLocationUrl: String
    ) {
        callback.onRedirectReceived(request, info, newLocationUrl);
    }

    override fun onResponseStarted(request: UrlRequest?, info: UrlResponseInfo) {
        callback.onResponseStarted(request, info);
    }

    override fun onReadCompleted(
        request: UrlRequest,
        info: UrlResponseInfo,
        byteBuffer: ByteBuffer
    ) {
        callback.onReadCompleted(request, info, byteBuffer);
    }

    override fun onSucceeded(request: UrlRequest, info: UrlResponseInfo?) {
        callback.onSucceeded(request, info);
    }

    override fun onFailed(
        request: UrlRequest,
        info: UrlResponseInfo?,
        error: CronetException
    ) {
        callback.onFailed(request, info, error);
    }
}
