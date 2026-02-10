// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Block type for response delivery.
/// Called once when response headers are received, or with an error on failure.
typedef void (^CUPHTTPResponseBlock)(NSURLResponse * _Nullable response,
                                      NSError * _Nullable error);

/// Block type for data chunk delivery.
/// Called repeatedly as data chunks arrive.
typedef void (^CUPHTTPDataBlock)(NSData * data);

/// Block type for completion.
/// Called once when the request completes (with error on failure).
typedef void (^CUPHTTPCompletionBlock)(NSError * _Nullable error);

/// A streaming HTTP task helper for externally-managed URLSessions.
@interface CUPHTTPStreamingTask : NSObject

/// Whether to automatically follow redirects.
@property (nonatomic, readonly) NSInteger numRedirects;

/// Maximum number of redirects to follow.
@property (nonatomic, readonly, nullable) NSURL *lastURL;

/// Creates a new streaming task with callback blocks.
///
/// @param session The URLSession to use (can be externally managed)
/// @param request The URL request to execute
/// @param onResponse Called once when response headers are available, or with error
/// @param onData Called repeatedly with buffered data chunks
/// @param onComplete Called once when the request completes
/// @param followRedirects Whether to automatically follow redirects (default: true)
/// @param maxRedirects Maximum number of redirects to follow (default: 5)
- (instancetype)initWithSession:(NSURLSession *)session
                        request:(NSURLRequest *)request
                     onResponse:(CUPHTTPResponseBlock _Nullable)onResponse
                         onData:(CUPHTTPDataBlock _Nullable)onData
                     onComplete:(CUPHTTPCompletionBlock _Nullable)onComplete
                followRedirects:(BOOL)followRedirects
                   maxRedirects:(NSInteger)maxRedirects;

/// Starts the streaming request.
- (void)start;

/// Cancels the in-flight request.
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
