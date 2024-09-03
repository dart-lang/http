// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

package com.example.ok_http

import java.io.IOException
import java.io.InputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future


/**
 * Callback interface utilized by the [AsyncInputStreamReader].
 */
interface DataCallback {
    fun onDataRead(data: ByteArray)
    fun onFinished()
    fun onError(e: IOException)
}

/**
 * Provides functions to read data from an InputStream asynchronously.
 */
class AsyncInputStreamReader {
    private val executorService: ExecutorService = Executors.newSingleThreadExecutor()

    /**
     * Reads data from an InputStream asynchronously using an executor service.
     *
     * @param inputStream The InputStream to read from
     * @param callback The DataCallback to call when data is read, finished, or an error occurs
     *
     * @return Future<*>
     */
    fun readAsync(inputStream: InputStream, callback: DataCallback): Future<*> {
        return executorService.submit {
            try {
                val buffer = ByteArray(4096)
                var bytesRead: Int
                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                    val byteArray = buffer.copyOfRange(0, bytesRead)
                    callback.onDataRead(byteArray)
                }

            } catch (e: IOException) {
                callback.onError(e)
            } finally {
                try {
                    inputStream.close()
                } catch (e: IOException) {
                    callback.onError(e)
                }
                callback.onFinished()
            }
        }
    }

    fun shutdown() {
        executorService.shutdown()
    }
}
