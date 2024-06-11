// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// To cause a request failure [with a suitable message] due to too many redirects,
// we need to throw an IOException. This cannot be done using Dart JNI bindings,
// which lead to a deadlock and eventually a `java.net.SocketTimeoutException`.
// https://github.com/dart-lang/native/issues/561

package com.example.ok_http

import okhttp3.Interceptor
import okhttp3.OkHttpClient
import java.io.IOException

class RedirectInterceptor {
    companion object {

        /**
         * Adds a redirect interceptor to the OkHttpClient.Builder
         *
         * @param clientBuilder The `OkHttpClient.Builder` to add the interceptor to
         * @param maxRedirects The maximum number of redirects to follow
         * @param followRedirects Whether to follow redirects
         *
         * @return OkHttpClient.Builder
         */
        fun addRedirectInterceptor(
            clientBuilder: OkHttpClient.Builder, maxRedirects: Int, followRedirects: Boolean
        ): OkHttpClient.Builder {
            return clientBuilder.addInterceptor(Interceptor { chain ->

                var req = chain.request()
                var response = chain.proceed(req)
                var redirectCount = 0

                while (response.isRedirect && followRedirects) {
                    if (redirectCount > maxRedirects) {
                        throw IOException("Redirect limit exceeded")
                    }

                    val location = response.header("location")
                    req = req.newBuilder().url(location!!).build()
                    response.close()
                    response = chain.proceed(req)
                    redirectCount++
                }

                response
            })
        }
    }
}
