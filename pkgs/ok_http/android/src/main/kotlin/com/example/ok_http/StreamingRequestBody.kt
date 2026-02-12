// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

package com.example.ok_http

import okhttp3.MediaType
import okhttp3.RequestBody
import okio.BufferedSink
import okio.Pipe
import okio.buffer
import java.io.IOException
import java.util.concurrent.Executors

/**
 * A [RequestBody] that receives data incrementally from Dart via [writeChunk],
 * using an [okio.Pipe] for backpressure between the Dart write side and the
 * OkHttp read side.
 *
 * Flow:
 * 1. OkHttp calls [writeTo] on its dispatcher thread, which blocks reading
 *    from the pipe source until data is available or the source is closed.
 * 2. Dart calls [writeChunk] to push data into the pipe sink. The write
 *    happens on a dedicated executor thread so the Dart isolate is never
 *    blocked by pipe backpressure.
 * 3. [WriteCallback.onWriteComplete] fires after each chunk, signaling Dart
 *    to send the next chunk.
 * 4. [finish] closes the pipe sink, causing [writeTo]'s writeAll to complete.
 * 5. [cancel] aborts the pipe and shuts down the executor for early
 *    termination (e.g., server responded 413 before body was fully sent).
 */
class StreamingRequestBody(
    private val mediaType: MediaType?,
    private val length: Long,
    bufferSize: Long = 65536
) : RequestBody() {
    private val pipe = Pipe(bufferSize)
    private val bufferedSink = pipe.sink.buffer()
    private val executor = Executors.newSingleThreadExecutor()

    override fun contentType(): MediaType? = mediaType

    override fun contentLength(): Long = length

    override fun isOneShot(): Boolean = true

    override fun writeTo(sink: BufferedSink) {
        sink.writeAll(pipe.source)
    }

    /**
     * Write a chunk of data to the pipe asynchronously.
     * The callback fires when the write completes, providing backpressure.
     */
    fun writeChunk(data: ByteArray, length: Int, callback: WriteCallback) {
        executor.submit {
            try {
                bufferedSink.write(data, 0, length)
                bufferedSink.flush()
                callback.onWriteComplete()
            } catch (e: IOException) {
                callback.onError(e)
            }
        }
    }

    /**
     * Signal that all data has been written. Closes the pipe sink,
     * which causes [writeTo]'s writeAll to complete.
     */
    fun finish() {
        executor.submit { bufferedSink.close() }
        executor.shutdown()
    }

    /**
     * Cancel the streaming and close resources.
     */
    fun cancel() {
        try { pipe.cancel() } catch (_: Exception) {}
        executor.shutdownNow()
    }
}
