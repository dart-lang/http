// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation

/// A WebSocket task helper for externally-managed URLSessions.
///
/// Uses iOS 15+ / macOS 12+ per-task delegates to receive WebSocket lifecycle
/// events (open, close, completion) without requiring a session-level delegate.
@objc(CUPHTTPWebSocketTask)
public class CUPHTTPWebSocketTask: NSObject {
    private let session: URLSession
    private let request: URLRequest

    /// The underlying WebSocket task. Available after `start()` is called.
    @objc public private(set) var webSocketTask: URLSessionWebSocketTask?

    /// Strong reference keeps delegate alive for the task's lifetime.
    private var taskDelegate: (any URLSessionWebSocketDelegate)?

    /// Callbacks (held strongly until delivered, then nilled out).
    private var onOpen: ((String?) -> Void)?
    private var onClose: ((Int, NSData?) -> Void)?
    private var onComplete: ((NSError?) -> Void)?

    @objc
    public init(
        session: URLSession,
        request: URLRequest,
        onOpen: ((String?) -> Void)?,
        onClose: ((Int, NSData?) -> Void)?,
        onComplete: ((NSError?) -> Void)?
    ) {
        self.session = session
        self.request = request
        self.onOpen = onOpen
        self.onClose = onClose
        self.onComplete = onComplete
        super.init()
    }

    /// Starts the WebSocket connection.
    ///
    /// Creates the underlying `URLSessionWebSocketTask`, assigns a per-task
    /// delegate, and resumes the task. On iOS < 15 / macOS < 12, delivers an
    /// error through `onComplete` since per-task delegates are not available.
    @objc
    public func start() {
        if #available(iOS 15.0, macOS 12.0, *) {
            startWithTaskDelegate()
        } else {
            let error = NSError(
                domain: "CUPHTTPWebSocketTask",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Per-task WebSocket delegates require iOS 15+ / macOS 12+"
                ]
            )
            let cb = onComplete
            onComplete = nil
            onOpen = nil
            onClose = nil
            cb?(error)
        }
    }

    /// Cancels the WebSocket connection.
    @objc
    public func cancel() {
        webSocketTask?.cancel()
    }

    @available(iOS 15.0, macOS 12.0, *)
    private func startWithTaskDelegate() {
        let delegate = _WebSocketTaskDelegate(
            onOpen: onOpen,
            onClose: onClose,
            onComplete: onComplete
        )
        onOpen = nil
        onClose = nil
        onComplete = nil

        let task = session.webSocketTask(with: request)
        task.delegate = delegate
        self.taskDelegate = delegate
        self.webSocketTask = task
        task.resume()
    }
}

/// Per-task delegate that handles WebSocket lifecycle events.
///
/// Note: any delegate method implemented here will be used in place of a
/// session-level delegate's implementation for this task. As such, adding
/// overrides is effectively a breaking change.
@available(iOS 15.0, macOS 12.0, *)
private final class _WebSocketTaskDelegate: NSObject, URLSessionWebSocketDelegate {
    private var onOpen: ((String?) -> Void)?
    private var onClose: ((Int, NSData?) -> Void)?
    private var onComplete: ((NSError?) -> Void)?

    init(
        onOpen: ((String?) -> Void)?,
        onClose: ((Int, NSData?) -> Void)?,
        onComplete: ((NSError?) -> Void)?
    ) {
        self.onOpen = onOpen
        self.onClose = onClose
        self.onComplete = onComplete
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        let cb = onOpen
        onOpen = nil
        cb?(`protocol`)
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let cb = onClose
        onClose = nil
        cb?(closeCode.rawValue, reason as NSData?)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let nsError = error.map { $0 as NSError }

        let cb = onComplete
        onComplete = nil
        onOpen = nil
        onClose = nil
        cb?(nsError)
    }
}
