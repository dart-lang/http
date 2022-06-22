// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Normally, we'd "import <Foundation/Foundation.h>"
// but that would mean that ffigen would process every file in the Foundation
// framework, which is huge. So just import the headers that we need.
#import <Foundation/NSObject.h>
#import <Foundation/NSURLSession.h>


/**
 * An object used to communicate redirect information to Dart code.
 *
 * The flow is:
 *  1. CUPHTTPClientDelegate receives a message from the URL Loading System.
 *  2. CUPHTTPClientDelegate creates a new CUPHTTPForwardedDelegate subclass.
 *  3. CUPHTTPClientDelegate sends the CUPHTTPForwardedDelegate to the
 *    configured Dart_Port.
 *  4. CUPHTTPClientDelegate waits on CUPHTTPForwardedDelegate.lock
 *  5. When the Dart code is done process the message received on the port,
 *    it calls [CUPHTTPForwardedDelegate finish*], which releases the lock.
 *  6. CUPHTTPClientDelegate continues running.
 */
@interface CUPHTTPForwardedDelegate : NSObject
- (id) initWithSession:(NSURLSession *)session
                  task:(NSURLSessionTask *) task;

/**
 * Indicates that the task should continue executing using the given request.
 */
- (void) finish;;

@property (readonly) NSURLSession *session;
@property (readonly) NSURLSessionTask *task;

// This property is meant to be used only by CUPHTTPClientDelegate.
@property (readonly) NSLock *lock;

@end

@interface CUPHTTPForwardedRedirect : CUPHTTPForwardedDelegate

- (id) initWithSession:(NSURLSession *)session
                  task:(NSURLSessionTask *) task
              response:(NSHTTPURLResponse *)response
               request:(NSURLRequest *)request;

/**
 * Indicates that the task should continue executing using the given request.
 * If the request is NIL then the redirect is not followed and the task is
 * complete.
 */
- (void) finishWithRequest:(NSURLRequest *) request;

@property (readonly) NSHTTPURLResponse *response;
@property (readonly) NSURLRequest *request;

// This property is meant to be used only by CUPHTTPClientDelegate.
@property (readonly) NSURLRequest *redirectRequest;

@end

@interface CUPHTTPForwardedResponse : CUPHTTPForwardedDelegate

- (id) initWithSession:(NSURLSession *)session
                  task:(NSURLSessionTask *) task
              response:(NSURLResponse *)response;

- (void) finishWithDisposition:(NSURLSessionResponseDisposition) disposition;

@property (readonly) NSURLResponse *response;

// This property is meant to be used only by CUPHTTPClientDelegate.
@property (readonly) NSURLSessionResponseDisposition disposition;

@end

@interface CUPHTTPForwardedData : CUPHTTPForwardedDelegate

- (id) initWithSession:(NSURLSession *)session
                  task:(NSURLSessionTask *) task
                  data:(NSData *)data;

@property (readonly) NSData* data;

@end


@interface CUPHTTPForwardedComplete : CUPHTTPForwardedDelegate

- (id) initWithSession:(NSURLSession *)session
                  task:(NSURLSessionTask *) task
                 error:(NSError *)error;

@property (readonly) NSError* error;

@end
