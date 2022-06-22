// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#import "CUPHTTPForwardedDelegate.h"

#import <Foundation/Foundation.h>
#include <os/log.h>

@implementation CUPHTTPForwardedDelegate

- (id) initWithSession:(NSURLSession *)session
                  task:(NSURLSessionTask *) task {
  self = [super init];
  if (self != nil) {
    self->_session = [session retain];
    self->_task = [task retain];
    self->_lock = [NSLock new];
  }
  return self;
}

- (void) dealloc {
  [self->_session release];
  [self->_task release];
  [self->_lock release];
  [super dealloc];
}

- (void) finish {
  [self->_lock unlock];
}

@end

@implementation CUPHTTPForwardedRedirect

- (id) initWithSession:(NSURLSession *)session
                  task:(NSURLSessionTask *) task
              response:(NSHTTPURLResponse *)response
               request:(NSURLRequest *)request{
  self = [super initWithSession: session task: task];
  if (self != nil) {
    self->_response = [response retain];
    self->_request = [request retain];
  }
  return self;
}

- (void) dealloc {
  [self->_response release];
  [self->_request release];
  [super dealloc];
}

- (void) finishWithRequest:(NSURLRequest *) request {
  self->_redirectRequest = [request retain];
  [super finish];
}

@end

@implementation CUPHTTPForwardedResponse

- (id) initWithSession:(NSURLSession *)session
                  task:(NSURLSessionTask *) task
              response:(NSURLResponse *)response {
  self = [super initWithSession: session task: task];
  if (self != nil) {
    self->_response = [response retain];
  }
  return self;
}

- (void) dealloc {
  [self->_response release];
  [super dealloc];
}

- (void) finishWithDisposition:(NSURLSessionResponseDisposition) disposition {
  self->_disposition = disposition;
  [super finish];
}

@end

@implementation CUPHTTPForwardedData

- (id) initWithSession:(NSURLSession *)session
                  task:(NSURLSessionTask *) task
                  data:(NSData *)data {
  self = [super initWithSession: session task: task];
  if (self != nil) {
    self->_data = [data retain];
  }
  return self;
}

- (void) dealloc {
  [self->_data release];
  [super dealloc];
}

@end

@implementation CUPHTTPForwardedComplete

- (id) initWithSession:(NSURLSession *)session
                  task:(NSURLSessionTask *) task
                 error:(NSError *)error {
  self = [super initWithSession: session task: task];
  if (self != nil) {
    self->_error = [error retain];
  }
  return self;
}

- (void) dealloc {
  [self->_error release];
  [super dealloc];
}

@end
