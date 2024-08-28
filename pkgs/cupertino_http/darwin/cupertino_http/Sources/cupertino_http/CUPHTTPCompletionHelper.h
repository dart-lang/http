// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Normally, we'd "import <Foundation/Foundation.h>"
// but that would mean that ffigen would process every file in the Foundation
// framework, which is huge. So just import the headers that we need.
#import <Foundation/NSObject.h>
#import <Foundation/NSURLSession.h>

#include "dart-sdk/include/dart_api_dl.h"

/**
 * Creates a `Dart_CObject` containing the given `NSObject` pointer as an int.
 */
Dart_CObject NSObjectToCObject(NSObject* n);

/**
 * Executes [NSURLSessionWebSocketTask sendMessage:completionHandler:] and
 * sends the results of the completion handler to the given `Dart_Port`.
 */
extern void CUPHTTPSendMessage(NSURLSessionWebSocketTask *task,
                               NSURLSessionWebSocketMessage *message,
                               Dart_Port sendPort);

/**
 * Executes [NSURLSessionWebSocketTask receiveMessageWithCompletionHandler:]
 * and sends the results of the completion handler to the given `Dart_Port`.
 */
extern void CUPHTTPReceiveMessage(NSURLSessionWebSocketTask *task,
                                  Dart_Port sendPort);
