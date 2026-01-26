// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation
import os

/// A streaming HTTP task helper for externally-managed URLSessions.
///
/// Provides chunk-based response delivery using the modern `bytes(for:)` API
/// on iOS 15+/macOS 12+, with fallback chunking on older versions.
@objc(CUPHTTPStreamingTask)
public class CUPHTTPStreamingTask: NSObject {
    private let session: URLSession
    private let request: URLRequest
    private let chunkSize: Int

    /// Internal data task reference for cancellation (legacy path)
    private var dataTask: URLSessionDataTask?

    /// Swift Task handle for async cancellation (iOS 15+)
    /// Using Any to avoid @available requirement on stored property
    private var asyncTask: Any?

    /// Callbacks (held strongly during request)
    /// No need for synchronization since they're only used sequentially in the task
    private var onResponse: ((URLResponse?, NSError?) -> Void)?
    private var onData: ((NSData) -> Void)?
    private var onComplete: ((NSError?) -> Void)?

    /// Creates a new streaming task with callback blocks.
    ///
    /// - Parameters:
    ///   - session: The URLSession to use (can be externally managed)
    ///   - request: The URL request to execute
    ///   - chunkSize: Buffer size before delivering to callback (default 64KB)
    ///   - onResponse: Called once when response headers are available
    ///   - onData: Called repeatedly with buffered data chunks
    ///   - onComplete: Called once when the request completes
    @objc
    public init(
        session: URLSession,
        request: URLRequest,
        onResponse: ((URLResponse?, NSError?) -> Void)?,
        onData: ((NSData) -> Void)?,
        onComplete: ((NSError?) -> Void)?,
        chunkSize: Int = 65536
    ) {
        self.session = session
        self.request = request
        self.onResponse = onResponse
        self.onData = onData
        self.onComplete = onComplete
        self.chunkSize = chunkSize
        super.init()
    }

    /// Starts the streaming request.
    @objc
    public func start() {
        if #available(iOS 15.0, macOS 12.0, *) {
            startWithAsyncBytes()
        } else {
            startWithLegacyFallback()
        }
    }

    /// Cancels the in-flight request.
    @objc
    public func cancel() {
        // Cancel the async Task if available (iOS 15+ path)
        if #available(iOS 15.0, macOS 12.0, *) {
            if let task = asyncTask as? Task<Void, Never> {
                task.cancel()
            }
        } else {
            dataTask?.cancel()
        }
    }

    @available(iOS 15.0, macOS 12.0, *)
    private func startWithAsyncBytes() {
        asyncTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                let (asyncBytes, response) = try await self.session.bytes(for: self.request)

                // Deliver response metadata first
                self.deliverResponse(response, error: nil)

                let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: self.chunkSize)
                defer { buffer.deallocate() }
                var offset = 0

                for try await byte in asyncBytes {
                    buffer[offset] = byte
                    offset += 1
                    if offset >= chunkSize {
                        if Task.isCancelled { break }
                        self.deliverData(Data(bytes: buffer.baseAddress!, count: offset))
                        offset = 0
                    }
                }

                // Flush remaining buffer
                if offset > 0 {
                    self.deliverData(Data(bytes: buffer.baseAddress!, count: offset))
                }

                self.deliverCompletion(error: nil)

            } catch {
                if !Task.isCancelled {
                    let nsError = error as NSError
                    self.deliverResponse(nil, error: nsError)
                    self.deliverCompletion(error: nsError)
                }
            }
        }
    }

    /// Fallback for older OS versions that don't have bytes(for:).
    ///
    /// Uses dataTask(with:completionHandler:) which buffers the entire response
    /// before calling the handler. No true streaming on iOS 13-14.
    private func startWithLegacyFallback() {
        dataTask = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.deliverResponse(response, error: error as NSError)
                self.deliverCompletion(error: error as NSError)
                return
            }

            self.deliverResponse(response, error: nil)

            if let data = data {
                self.deliverData(data)
            }

            self.deliverCompletion(error: nil)
        }

        dataTask?.resume()
    }

    private func deliverResponse(_ response: URLResponse?, error: NSError?) {
        let cb = onResponse
        onResponse = nil  // One-shot callback
        cb?(response, error)
    }

    private func deliverData(_ data: Data) {
        onData?(data as NSData)
    }

    private func deliverCompletion(error: NSError?) {
        let cb = onComplete
        onComplete = nil  // One-shot callback
        onData = nil  // Release reference
        cb?(error)
    }
}
