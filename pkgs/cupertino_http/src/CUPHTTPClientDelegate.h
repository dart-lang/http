// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Normally, we'd "import <Foundation/Foundation.h>"
// but that would mean that ffigen would process every file in the Foundation
// framework, which is huge. So just import the headers that we need.
#import <Foundation/NSObject.h>
#import <Foundation/NSURLSession.h>

#include "dart-sdk/include/dart_api_dl.h"

/**
 * The type of message being sent to a Dart port. See CUPHTTPClientDelegate.
 */
typedef NS_ENUM(NSInteger, MessageType) {
  ResponseMessage = 0,
  DataMessage = 1,
  CompletedMessage = 2,
  RedirectMessage = 3,
};

/**
 * The configuration associated with a NSURLSessionTask.
 * See CUPHTTPClientDelegate.
 */
@interface CUPHTTPTaskConfiguration : NSObject

- (id) initWithPort:(Dart_Port)sendPort;

@property (readonly) Dart_Port sendPort;

@end

/**
 * A delegate for NSURLSession that forwards events for registered
 * NSURLSessionTasks and forwards them to a port for consumption in Dart.
 *
 * The messages sent to the port are contained in a List with one of 3
 * possible formats:
 *
 * 1. When the delegate receives a HTTP redirect response:
 *    [MessageType::RedirectMessage, <int: pointer to CUPHTTPForwardedRedirect>]
 *
 * 2. When the delegate receives a HTTP response:
 *    [MessageType::ResponseMessage, <int: pointer to CUPHTTPForwardedResponse>]
 *
 * 3. When the delegate receives some HTTP data:
 *    [MessageType::DataMessage, <int: pointer to CUPHTTPForwardedData>]
 *
 * 4. When the delegate is informed that the response is complete:
 *    [MessageType::CompletedMessage, <int: pointer to CUPHTTPForwardedComplete>]
 */
@interface CUPHTTPClientDelegate : NSObject

/**
 * Instruct the delegate to forward events for the given task to the port
 * specified in the configuration.
 */
- (void)registerTask:(NSURLSessionTask *)task
   withConfiguration:(CUPHTTPTaskConfiguration *)config;
@end
