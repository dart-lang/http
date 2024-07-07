// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

package com.example.ok_http

import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString

/**
 * `OkHttp` expects a subclass of the abstract class [`WebSocketListener`](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-web-socket-listener/index.html)
 * to be passed to the `newWebSocket` method.
 *
 * `package:jnigen` does not support the ability to subclass abstract Java classes in Dart
 * (see https://github.com/dart-lang/jnigen/issues/348).
 *
 * This file provides an interface `WebSocketListener`, which can
 * be implemented in Dart and a wrapper class `WebSocketListenerProxy`, which
 * can be passed to the OkHttp API.
 */
class WebSocketListenerProxy(private val listener: WebSocketListener) : WebSocketListener() {
    interface WebSocketListener {
        fun onOpen(webSocket: WebSocket, response: Response)
        fun onMessage(webSocket: WebSocket, text: String)
        fun onMessage(webSocket: WebSocket, bytes: ByteString)
        fun onClosing(webSocket: WebSocket, code: Int, reason: String)
        fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?)
    }

    override fun onOpen(webSocket: WebSocket, response: Response) {
        listener.onOpen(webSocket, response)
    }

    override fun onMessage(webSocket: WebSocket, text: String) {
        listener.onMessage(webSocket, text)
    }

    override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
        listener.onMessage(webSocket, bytes)
    }

    override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
        listener.onClosing(webSocket, code, reason)
    }

    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
        listener.onFailure(webSocket, t, response)
    }
}
