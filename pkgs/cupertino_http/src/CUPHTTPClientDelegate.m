// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#import "CUPHTTPClientDelegate.h"

#import <Foundation/Foundation.h>
#include <os/log.h>

#import "CUPHTTPCompletionHelper.h"
#import "CUPHTTPForwardedDelegate.h"

static Dart_CObject MessageTypeToCObject(MessageType messageType) {
  Dart_CObject cobj;
  cobj.type = Dart_CObject_kInt64;
  cobj.value.as_int64 = messageType;
  return cobj;
}

@implementation CUPHTTPTaskConfiguration

- (id) initWithPort:(Dart_Port)sendPort {
  self = [super init];
  if (self != nil) {
    self->_sendPort = sendPort;
  }
  return self;
}

@end

@implementation CUPHTTPClientDelegate {
  NSMapTable<NSURLSessionTask *, CUPHTTPTaskConfiguration *> *taskConfigurations;
}

- (instancetype)init {
  self = [super init];
  if (self != nil) {
    taskConfigurations = [[NSMapTable strongToStrongObjectsMapTable] retain];
  }
  return self;
}

- (void)dealloc {
  [taskConfigurations release];
  [super dealloc];
}

- (void)registerTask:(NSURLSessionTask *) task
   withConfiguration:(CUPHTTPTaskConfiguration *)config {
  [taskConfigurations setObject:config forKey:task];
}

-(void)unregisterTask:(NSURLSessionTask *) task {
  [taskConfigurations removeObjectForKey:task];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
  CUPHTTPTaskConfiguration *config = [taskConfigurations objectForKey:task];
  NSAssert(config != nil, @"No configuration for task.");

  CUPHTTPForwardedRedirect *forwardedRedirect = [[CUPHTTPForwardedRedirect alloc]
                                                 initWithSession:session task:task
                                                 response:response request:request];
  Dart_CObject ctype = MessageTypeToCObject(RedirectMessage);
  Dart_CObject credirect = NSObjectToCObject(forwardedRedirect);
  Dart_CObject* message_carray[] = { &ctype, &credirect };
  
  Dart_CObject message_cobj;
  message_cobj.type = Dart_CObject_kArray;
  message_cobj.value.as_array.length = 2;
  message_cobj.value.as_array.values = message_carray;
  
  [forwardedRedirect.lock lock];  // After this line, any attempt to acquire the lock will wait.
  const bool success = Dart_PostCObject_DL(config.sendPort, &message_cobj);
  NSAssert(success, @"Dart_PostCObject_DL failed.");
  
  // Will be unlocked by [CUPHTTPRedirect continueWithRequest:], which will
  // set `redirect.redirectRequest`.
  //
  // See the @interface description for CUPHTTPRedirect.
  [forwardedRedirect.lock lock];
  
  completionHandler(forwardedRedirect.redirectRequest);
  [forwardedRedirect release];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
  CUPHTTPTaskConfiguration *config = [taskConfigurations objectForKey:task];
  NSAssert(config != nil, @"No configuration for task.");
  
  CUPHTTPForwardedResponse *forwardedResponse = [[CUPHTTPForwardedResponse alloc]
                                                 initWithSession:session
                                                 task:task
                                                 response:response];
  
  
  Dart_CObject ctype = MessageTypeToCObject(ResponseMessage);
  Dart_CObject cRsponseReceived = NSObjectToCObject(forwardedResponse);
  Dart_CObject* message_carray[] = { &ctype, &cRsponseReceived };
  
  Dart_CObject message_cobj;
  message_cobj.type = Dart_CObject_kArray;
  message_cobj.value.as_array.length = 2;
  message_cobj.value.as_array.values = message_carray;
  
  [forwardedResponse.lock lock];  // After this line, any attempt to acquire the lock will wait.
  const bool success = Dart_PostCObject_DL(config.sendPort, &message_cobj);
  NSAssert(success, @"Dart_PostCObject_DL failed.");
  
  // Will be unlocked by [CUPHTTPRedirect continueWithRequest:], which will
  // set `redirect.redirectRequest`.
  //
  // See the @interface description for CUPHTTPRedirect.
  [forwardedResponse.lock lock];
  completionHandler(forwardedResponse.disposition);
  [forwardedResponse release];
}


- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task
    didReceiveData:(NSData *)data {
  CUPHTTPTaskConfiguration *config = [taskConfigurations objectForKey:task];
  NSAssert(config != nil, @"No configuration for task.");
  
  CUPHTTPForwardedData *forwardedData = [[CUPHTTPForwardedData alloc]
                                         initWithSession:session task:task data: data]
  ;
  
  Dart_CObject ctype = MessageTypeToCObject(DataMessage);
  Dart_CObject cReceiveData = NSObjectToCObject(forwardedData);
  Dart_CObject* message_carray[] = { &ctype, &cReceiveData };
  
  Dart_CObject message_cobj;
  message_cobj.type = Dart_CObject_kArray;
  message_cobj.value.as_array.length = 2;
  message_cobj.value.as_array.values = message_carray;
  
  [forwardedData.lock lock];  // After this line, any attempt to acquire the lock will wait.
  const bool success = Dart_PostCObject_DL(config.sendPort, &message_cobj);
  NSAssert(success, @"Dart_PostCObject_DL failed.");
  
  // Will be unlocked by [CUPHTTPRedirect continueWithRequest:], which will
  // set `redirect.redirectRequest`.
  //
  // See the @interface description for CUPHTTPRedirect.
  [forwardedData.lock lock];
  [forwardedData release];
}

- (void)URLSession:(NSURLSession *)session 
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
  CUPHTTPTaskConfiguration *config = [taskConfigurations objectForKey:downloadTask];
  NSAssert(config != nil, @"No configuration for task.");
  
  CUPHTTPForwardedFinishedDownloading *forwardedFinishedDownload = [
    [CUPHTTPForwardedFinishedDownloading alloc]
    initWithSession:session downloadTask:downloadTask url: location];
  
  Dart_CObject ctype = MessageTypeToCObject(FinishedDownloading);
  Dart_CObject cReceiveData = NSObjectToCObject(forwardedFinishedDownload);
  Dart_CObject* message_carray[] = { &ctype, &cReceiveData };
  
  Dart_CObject message_cobj;
  message_cobj.type = Dart_CObject_kArray;
  message_cobj.value.as_array.length = 2;
  message_cobj.value.as_array.values = message_carray;

  // After this line, any attempt to acquire the lock will wait.
  [forwardedFinishedDownload.lock lock];
  const bool success = Dart_PostCObject_DL(config.sendPort, &message_cobj);
  NSAssert(success, @"Dart_PostCObject_DL failed.");
  
  [forwardedFinishedDownload.lock lock];
  [forwardedFinishedDownload release];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
  CUPHTTPTaskConfiguration *config = [taskConfigurations objectForKey:task];
  NSAssert(config != nil, @"No configuration for task.");
  
  CUPHTTPForwardedComplete *forwardedComplete = [[CUPHTTPForwardedComplete alloc]
                                                 initWithSession:session task:task error: error];
  
  
  Dart_CObject ctype = MessageTypeToCObject(CompletedMessage);
  Dart_CObject cComplete = NSObjectToCObject(forwardedComplete);
  Dart_CObject* message_carray[] = { &ctype, &cComplete };
  
  Dart_CObject message_cobj;
  message_cobj.type = Dart_CObject_kArray;
  message_cobj.value.as_array.length = 2;
  message_cobj.value.as_array.values = message_carray;
  
  [forwardedComplete.lock lock];  // After this line, any attempt to acquire the lock will wait.
  const bool success = Dart_PostCObject_DL(config.sendPort, &message_cobj);
  NSAssert(success, @"Dart_PostCObject_DL failed.");
  
  // Will be unlocked by [CUPHTTPRedirect continueWithRequest:], which will
  // set `redirect.redirectRequest`.
  //
  // See the @interface description for CUPHTTPRedirect.
  [forwardedComplete.lock lock];
  [forwardedComplete release];
}

// https://developer.apple.com/documentation/foundation/nsurlsessionwebsocketdelegate?language=objc


- (void)URLSession:(NSURLSession *)session 
     webSocketTask:(NSURLSessionWebSocketTask *)task
didOpenWithProtocol:(NSString *)protocol {
  CUPHTTPTaskConfiguration *config = [taskConfigurations objectForKey:task];
  NSAssert(config != nil, @"No configuration for task.");
  
  CUPHTTPForwardedWebSocketOpened *opened = [[CUPHTTPForwardedWebSocketOpened alloc]
                                             initWithSession:session webSocketTask:task
                                             didOpenWithProtocol: protocol];

  Dart_CObject ctype = MessageTypeToCObject(WebSocketOpened);
  Dart_CObject cComplete = NSObjectToCObject(opened);
  Dart_CObject* message_carray[] = { &ctype, &cComplete };
  
  Dart_CObject message_cobj;
  message_cobj.type = Dart_CObject_kArray;
  message_cobj.value.as_array.length = 2;
  message_cobj.value.as_array.values = message_carray;
  
  [opened.lock lock];  // After this line, any attempt to acquire the lock will wait.
  const bool success = Dart_PostCObject_DL(config.sendPort, &message_cobj);
  NSAssert(success, @"Dart_PostCObject_DL failed.");
  
  [opened.lock lock];
  [opened release];
}


- (void)URLSession:(NSURLSession *)session 
     webSocketTask:(NSURLSessionWebSocketTask *)task
  didCloseWithCode:(NSURLSessionWebSocketCloseCode)closeCode
            reason:(NSData *)reason {
  CUPHTTPTaskConfiguration *config = [taskConfigurations objectForKey:task];
  NSAssert(config != nil, @"No configuration for task.");
  
  CUPHTTPForwardedWebSocketClosed *closed = [[CUPHTTPForwardedWebSocketClosed alloc]
                                             initWithSession:session webSocketTask:task
                                             code: closeCode
                                             reason: reason];
  
  Dart_CObject ctype = MessageTypeToCObject(WebSocketClosed);
  Dart_CObject cComplete = NSObjectToCObject(closed);
  Dart_CObject* message_carray[] = { &ctype, &cComplete };
  
  Dart_CObject message_cobj;
  message_cobj.type = Dart_CObject_kArray;
  message_cobj.value.as_array.length = 2;
  message_cobj.value.as_array.values = message_carray;
  
  [closed.lock lock];  // After this line, any attempt to acquire the lock will wait.
  const bool success = Dart_PostCObject_DL(config.sendPort, &message_cobj);
  NSAssert(success, @"Dart_PostCObject_DL failed.");
  
  [closed.lock lock];
  [closed release];
}

@end
