// todo add header
package com.example.ok_http



import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response

// todo add docs
interface WSInterceptedCallback {
    fun onWS(request: Request, response: Response)
}

// todo add docs
class WSInterceptor {
    companion object {
        fun addWSInterceptor(
            clientBuilder: OkHttpClient.Builder,
            callback: WSInterceptedCallback,
        ): OkHttpClient.Builder {
            return clientBuilder.addInterceptor(Interceptor { chain ->
                val request = chain.request()
                val response = chain.proceed(request)

                callback.onWS(request, response)

                response
                    .newBuilder()
                    .removeHeader("sec-websocket-extensions")
                    .addHeader("sec-websocket-extensions", "permessage-deflate")
                    .build()
            })
        }
    }
}
