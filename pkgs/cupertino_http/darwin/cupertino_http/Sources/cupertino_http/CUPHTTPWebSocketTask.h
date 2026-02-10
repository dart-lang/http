// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Block type for WebSocket open event.
/// Called once when the WebSocket handshake completes successfully.
/// @param protocol The negotiated subprotocol, or nil if none was selected.
typedef void (^CUPHTTPWebSocketOpenBlock)(NSString * _Nullable protocol);

/// Block type for WebSocket close event.
/// Called when the peer sends a close frame.
/// @param closeCode The close code from the peer.
/// @param reason The close reason data, or nil.
typedef void (^CUPHTTPWebSocketCloseBlock)(NSInteger closeCode,
                                            NSData * _Nullable reason);

/// Block type for task completion.
/// Called once when the task completes (with error on failure).
typedef void (^CUPHTTPWebSocketCompletionBlock)(NSError * _Nullable error);

/// A WebSocket task helper for externally-managed URLSessions.
///
/// Uses iOS 15+ / macOS 12+ per-task delegates to receive WebSocket lifecycle
/// events (open, close, completion) without requiring a session-level delegate.
@interface CUPHTTPWebSocketTask : NSObject

/// The underlying WebSocket task. Available after -start is called.
@property (nonatomic, readonly, nullable) NSURLSessionWebSocketTask *webSocketTask;

/// Creates a new WebSocket task with callback blocks.
///
/// @param session The URLSession to use (can be externally managed)
/// @param request The URL request for the WebSocket connection (may include custom headers)
/// @param onOpen Called once when the WebSocket handshake succeeds
/// @param onClose Called when the peer sends a close frame
/// @param onComplete Called once when the task completes
- (instancetype)initWithSession:(NSURLSession *)session
                        request:(NSURLRequest *)request
                         onOpen:(CUPHTTPWebSocketOpenBlock _Nullable)onOpen
                        onClose:(CUPHTTPWebSocketCloseBlock _Nullable)onClose
                     onComplete:(CUPHTTPWebSocketCompletionBlock _Nullable)onComplete;

/// Starts the WebSocket connection (creates and resumes the task).
- (void)start;

/// Cancels the WebSocket connection.
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
