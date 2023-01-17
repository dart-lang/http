// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

package io.flutter.plugins.cronet_http

import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import org.chromium.net.CronetEngine
import org.chromium.net.CronetException
import org.chromium.net.UploadDataProviders
import org.chromium.net.UrlRequest
import org.chromium.net.UrlResponseInfo
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class CronetHttpPlugin : FlutterPlugin, Messages.HttpApi {
    private lateinit var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding

    private val engineIdToEngine = HashMap<String, CronetEngine>()
    private val executor = Executors.newCachedThreadPool()
    private val mainThreadHandler = Handler(Looper.getMainLooper())
    private val channelId = AtomicInteger(0)
    private val engineId = AtomicInteger(0)

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    ) {
        Messages.HttpApi.setup(flutterPluginBinding.binaryMessenger, this)
        this.flutterPluginBinding = flutterPluginBinding
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        Messages.HttpApi.setup(binding.binaryMessenger, null)
    }

    override fun createEngine(createRequest: Messages.CreateEngineRequest): Messages.CreateEngineResponse {
        try {
            val builder = CronetEngine.Builder(flutterPluginBinding.getApplicationContext())

            if (createRequest.getStoragePath() != null) {
                builder.setStoragePath(createRequest.getStoragePath()!!)
            }

            if (createRequest.getCacheMode() == Messages.CacheMode.disabled) {
                builder.enableHttpCache(createRequest.getCacheMode()!!.ordinal, 0)
            } else if (createRequest.getCacheMode() != null && createRequest.getCacheMaxSize() != null) {
                builder.enableHttpCache(createRequest.getCacheMode()!!.ordinal, createRequest.getCacheMaxSize()!!)
            }

            if (createRequest.getEnableBrotli() != null) {
                builder.enableBrotli(createRequest.getEnableBrotli()!!)
            }

            if (createRequest.getEnableHttp2() != null) {
                builder.enableHttp2(createRequest.getEnableHttp2()!!)
            }

            if (createRequest.getEnablePublicKeyPinningBypassForLocalTrustAnchors() != null) {
                builder.enablePublicKeyPinningBypassForLocalTrustAnchors(createRequest.getEnablePublicKeyPinningBypassForLocalTrustAnchors()!!)
            }

            if (createRequest.getEnableQuic() != null) {
                builder.enableQuic(createRequest.getEnableQuic()!!)
            }

            if (createRequest.getUserAgent() != null) {
                builder.setUserAgent(createRequest.getUserAgent()!!)
            }

            val engine = builder.build()
            val engineName = "cronet_engine_" + engineId.incrementAndGet()
            engineIdToEngine.put(engineName, engine)
            return Messages.CreateEngineResponse.Builder()
                .setEngineId(engineName)
                .build()
        } catch (e: IllegalArgumentException) {
            return Messages.CreateEngineResponse.Builder()
                .setErrorString(e.message)
                .setErrorType(Messages.ExceptionType.illegalArgumentException)
                .build()
        } catch (e: Exception) {
            return Messages.CreateEngineResponse.Builder()
                .setErrorString(e.message)
                .setErrorType(Messages.ExceptionType.otherException)
                .build()
        }
    }

    override fun freeEngine(engineId: String) {
        engineIdToEngine.remove(engineId)
    }

    private fun createRequest(startRequest: Messages.StartRequest, cronetEngine: CronetEngine, eventSink: EventChannel.EventSink): UrlRequest {
        var numRedirects = 0

        val cronetRequest = cronetEngine.newUrlRequestBuilder(
            startRequest.url,
            object : UrlRequest.Callback() {
                override fun onRedirectReceived(
                    request: UrlRequest,
                    info: UrlResponseInfo,
                    newLocationUrl: String
                ) {
                    if (!startRequest.getFollowRedirects()) {
                        request.cancel()
                        mainThreadHandler.post({
                            eventSink.success(
                                Messages.EventMessage.Builder()
                                    .setType(Messages.EventMessageType.responseStarted)
                                    .setResponseStarted(
                                        Messages.ResponseStarted.Builder()
                                            .setStatusCode(info.getHttpStatusCode().toLong())
                                            .setStatusText(info.getHttpStatusText())
                                            .setHeaders(info.getAllHeaders())
                                            .setIsRedirect(true)
                                            .build()
                                    )
                                    .build()
                                    .toMap()
                            )
                        })
                    }
                    ++numRedirects
                    if (numRedirects <= startRequest.getMaxRedirects()) {
                        request.followRedirect()
                    } else {
                        request.cancel()
                        mainThreadHandler.post({
                            eventSink.success(
                                Messages.EventMessage.Builder()
                                    .setType(Messages.EventMessageType.tooManyRedirects)
                                    .build()
                                    .toMap()
                            )
                        })
                    }
                }

                override fun onResponseStarted(request: UrlRequest?, info: UrlResponseInfo) {
                    mainThreadHandler.post({
                        eventSink.success(
                            Messages.EventMessage.Builder()
                                .setType(Messages.EventMessageType.responseStarted)
                                .setResponseStarted(
                                    Messages.ResponseStarted.Builder()
                                        .setStatusCode(info.getHttpStatusCode().toLong())
                                        .setStatusText(info.getHttpStatusText())
                                        .setHeaders(info.getAllHeaders())
                                        .setIsRedirect(false)
                                        .build()
                                )
                                .build()
                                .toMap()
                        )
                    })
                    request?.read(ByteBuffer.allocateDirect(1024 * 1024))
                }

                override fun onReadCompleted(
                    request: UrlRequest,
                    info: UrlResponseInfo,
                    byteBuffer: ByteBuffer
                ) {
                    byteBuffer.flip()
                    val b = ByteArray(byteBuffer.remaining())
                    byteBuffer.get(b)
                    mainThreadHandler.post({
                        eventSink.success(
                            Messages.EventMessage.Builder()
                                .setType(Messages.EventMessageType.readCompleted)
                                .setReadCompleted(Messages.ReadCompleted.Builder().setData(b).build())
                                .build()
                                .toMap()
                        )
                    })
                    byteBuffer.clear()
                    request?.read(byteBuffer)
                }

                override fun onSucceeded(request: UrlRequest, info: UrlResponseInfo?) {
                    mainThreadHandler.post({ eventSink.endOfStream() })
                }

                override fun onFailed(
                    request: UrlRequest,
                    info: UrlResponseInfo?,
                    error: CronetException
                ) {
                    mainThreadHandler.post({ eventSink.error("CronetException", error.toString(), null) })
                }
            },
            executor
        )

        if (startRequest.getBody().size > 0) {
            cronetRequest.setUploadDataProvider(
                UploadDataProviders.create(startRequest.getBody()),
                executor
            )
        }
        cronetRequest.setHttpMethod(startRequest.getMethod())
        for ((key, value) in startRequest.getHeaders()) {
            cronetRequest.addHeader(key, value)
        }
        return cronetRequest.build()
    }

    override fun start(startRequest: Messages.StartRequest): Messages.StartResponse {
        // Create a unique channel to communicate Cronet events to the Dart client code with.
        val channelName = "plugins.flutter.io/cronet_event/" + channelId.incrementAndGet()
        val eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, channelName)

        // Don't start the Cronet request until the Dart client code is listening for events.
        val streamHandler =
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    try {
                        val cronetEngine = engineIdToEngine.getValue(startRequest.engineId)
                        val cronetRequest = createRequest(startRequest, cronetEngine, events)
                        cronetRequest.start()
                    } catch (e: Exception) {
                        mainThreadHandler.post({ events.error("CronetException", e.toString(), null) })
                    }
                }

                override fun onCancel(arguments: Any?) {}
            }
        eventChannel.setStreamHandler(streamHandler)

        return Messages.StartResponse.Builder().setEventChannel(channelName).build()
    }

    override fun dummy(arg1: Messages.EventMessage) {}
}
