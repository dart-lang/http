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
    private lateinit var cronetEngine: CronetEngine

    private val executor = Executors.newCachedThreadPool()
    private val mainThreadHandler = Handler(Looper.getMainLooper())
    private val channelId = AtomicInteger(0)

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    ) {
        Messages.HttpApi.setup(flutterPluginBinding.binaryMessenger, this)
        this.flutterPluginBinding = flutterPluginBinding
        val context = flutterPluginBinding.getApplicationContext()

        // TODO: Move the Cronet initialization elsewhere so that failures (e.g. because the device
        // doesn't have Google Play services) can be communicated to the Dart client.
        val builder = CronetEngine.Builder(context)
        cronetEngine = builder.build()
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        Messages.HttpApi.setup(binding.binaryMessenger, null)
    }

    override fun start(startRequest: Messages.StartRequest): Messages.StartResponse {
        // Create a unique channel to communicate Cronet events to the Dart client code with.
        val channelName = "plugins.flutter.io/cronet_event/" + channelId.incrementAndGet()
        val eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, channelName)
        lateinit var eventSink: EventChannel.EventSink
        var numRedirects = 0

        val cronetRequest =
            cronetEngine.newUrlRequestBuilder(
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
                        info: UrlResponseInfo,
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

        // Don't start the Cronet request until the Dart client code is listening for events.
        val streamHandler =
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    try {
                        cronetRequest.build().start()
                    } catch (e: Exception) {
                        mainThreadHandler.post({ eventSink.error("CronetException", e.toString(), null) })
                    }
                }

                override fun onCancel(arguments: Any?) {}
            }
        eventChannel.setStreamHandler(streamHandler)

        return Messages.StartResponse.Builder().setEventChannel(channelName).build()
    }

    override fun dummy(arg1: Messages.EventMessage) {}
}
