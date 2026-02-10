// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation

/// A streaming HTTP task helper for externally-managed URLSessions.
@objc(CUPHTTPStreamingTask)
public class CUPHTTPStreamingTask: NSObject {
    private let session: URLSession
    private let request: URLRequest

    /// Internal data task reference for cancellation
    private var dataTask: URLSessionDataTask?

    /// Strong reference keeps delegate alive for the task's lifetime.
    private var taskDelegate: _StreamingTaskDelegate?

    /// Callbacks (held strongly during request)
    /// No need for synchronization since they're only used sequentially in the task
    private var onResponse: ((URLResponse?, NSError?) -> Void)?
    private var onData: ((NSData) -> Void)?
    private var onComplete: ((NSError?) -> Void)?

    private let followRedirects: Bool
    private let maxRedirects: Int

    @objc public var numRedirects: Int { taskDelegate?.numRedirects ?? 0 }

    @objc public var lastURL: URL? { taskDelegate?.lastURL }

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
        followRedirects: Bool,
        maxRedirects: Int
    ) {
        self.session = session
        self.request = request
        self.onResponse = onResponse
        self.onData = onData
        self.onComplete = onComplete
        self.followRedirects = followRedirects
        self.maxRedirects = maxRedirects
        super.init()
    }

    /// Starts the streaming request.
    ///
    /// Requires iOS 15+ / macOS 12+ for per-task delegate support.
    @objc
    public func start() {
        guard #available(iOS 15.0, macOS 12.0, *) else {
            let error = NSError(
                domain: "CUPHTTPStreamingTask",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Per-task delegates require iOS 15+ / macOS 12+"
                ]
            )
            let cb = onComplete
            onComplete = nil
            onResponse = nil
            onData = nil
            cb?(error)
            return
        }

        let delegate = _StreamingTaskDelegate(
            onResponse: onResponse,
            onData: onData,
            onComplete: onComplete,
            followRedirects: followRedirects,
            maxRedirects: maxRedirects
        )
        onResponse = nil
        onData = nil
        onComplete = nil

        let task = session.dataTask(with: request)
        task.delegate = delegate
        self.taskDelegate = delegate
        self.dataTask = task
        task.resume()
    }

    /// Cancels the in-flight request.
    @objc
    public func cancel() {
        dataTask?.cancel()
    }
}

/// Per-task data delegate that handles only streaming delivery.
///
/// Note: any delegate method implemented here will be used in place of a 
/// session-level delegate's implementation. As such, adding overrides is
/// effectively a breaking change.
private final class _StreamingTaskDelegate: NSObject, URLSessionDataDelegate {
    private var onResponse: ((URLResponse?, NSError?) -> Void)?
    private var onData: ((NSData) -> Void)?
    private var onComplete: ((NSError?) -> Void)?
    private var responseDelivered = false

    private let followRedirects: Bool
    private let maxRedirects: Int
    var numRedirects = 0
    var lastURL: URL?

    init(
        onResponse: ((URLResponse?, NSError?) -> Void)?,
        onData: ((NSData) -> Void)?,
        onComplete: ((NSError?) -> Void)?,
        followRedirects: Bool,
        maxRedirects: Int
    ) {
        self.onResponse = onResponse
        self.onData = onData
        self.onComplete = onComplete
        self.followRedirects = followRedirects
        self.maxRedirects = maxRedirects
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        responseDelivered = true
        let cb = onResponse
        onResponse = nil
        cb?(response, nil)
        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        onData?(data as NSData)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let nsError = error.map { $0 as NSError }

        if !responseDelivered {
            let cb = onResponse
            onResponse = nil
            cb?(nil, nsError)
        }

        let cb = onComplete
        onComplete = nil
        onData = nil
        cb?(nsError)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        numRedirects += 1
        if followRedirects && numRedirects <= maxRedirects {
            lastURL = request.url
            completionHandler(request)
        } else {
            // Returning nil stops the redirect chain and treats the response as final.
            completionHandler(nil)
        }
    }
}