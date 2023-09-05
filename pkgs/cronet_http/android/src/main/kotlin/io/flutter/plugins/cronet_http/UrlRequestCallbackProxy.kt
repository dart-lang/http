// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

package io.flutter.plugins.cronet_http

import org.chromium.net.CronetException
import org.chromium.net.UrlRequest
import org.chromium.net.UrlResponseInfo
import java.nio.ByteBuffer


class UrlRequestCallbackProxy(val  callback : UrlRequestCallbackInterface) : UrlRequest.Callback() {
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
    }

    override fun onReadCompleted(
        request: UrlRequest,
        info: UrlResponseInfo,
        byteBuffer: ByteBuffer
    ) {
    }

    override fun onSucceeded(request: UrlRequest, info: UrlResponseInfo?) {
    }

    override fun onFailed(
        request: UrlRequest,
        info: UrlResponseInfo?,
        error: CronetException
    ) {
    }
}