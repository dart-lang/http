// TODO: add header
// TODO: add doc establishing why this exists (see cronet_http UrlRequestCallbackProxy)

package com.example.ok_http

import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString

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
