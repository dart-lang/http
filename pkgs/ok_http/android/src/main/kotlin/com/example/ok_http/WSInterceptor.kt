// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

package com.example.ok_http

import okhttp3.Interceptor
import okhttp3.OkHttpClient

/**
 * Usage of `chain.proceed(...)` via JNI Bindings leads to threading issues. This is a workaround
 * to intercept the response before it is parsed by the WebSocketReader, to prevent response parsing errors.
 */
class WSInterceptor {
    companion object {
        fun addWSInterceptor(
            clientBuilder: OkHttpClient.Builder
        ): OkHttpClient.Builder {
            return clientBuilder.addInterceptor(Interceptor { chain ->
                val request = chain.request()
                val response = chain.proceed(request)

                response.newBuilder()
                    // Removing this header to ensure that OkHttp does not fail due to unexpected values.
                    .removeHeader("sec-websocket-extensions")
                    // Adding the header to ensure successful parsing of the response.
                    .addHeader("sec-websocket-extensions", "permessage-deflate").build()
            })
        }
    }
}
