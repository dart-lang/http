// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#import "CUPHTTPCompletionHelper.h"

#import <Foundation/Foundation.h>
#include <os/log.h>

Dart_CObject NSObjectToCObject(NSObject* n) {
  Dart_CObject cobj;
  cobj.type = Dart_CObject_kInt64;
  cobj.value.as_int64 = (int64_t) n;
  return cobj;
}

void CUPHTTPSendMessage(NSURLSessionWebSocketTask *task, NSURLSessionWebSocketMessage *message,  Dart_Port sendPort) {
  [task sendMessage: message
  completionHandler: ^(NSError *error) {
    [error retain];
    Dart_CObject message_cobj = NSObjectToCObject(error);
    const bool success = Dart_PostCObject_DL(sendPort, &message_cobj);
    NSCAssert(success, @"Dart_PostCObject_DL failed.");
  }];
}

void CUPHTTPReceiveMessage(NSURLSessionWebSocketTask *task,  Dart_Port sendPort) {
  [task
   receiveMessageWithCompletionHandler: ^(NSURLSessionWebSocketMessage *message, NSError *error) {
    [message retain];
    [error retain];
    
    Dart_CObject cmessage = NSObjectToCObject(message);
    Dart_CObject cerror = NSObjectToCObject(error);
    Dart_CObject* message_carray[] = { &cmessage, &cerror };
    
    Dart_CObject message_cobj;
    message_cobj.type = Dart_CObject_kArray;
    message_cobj.value.as_array.length = 2;
    message_cobj.value.as_array.values = message_carray;
    
    const bool success = Dart_PostCObject_DL(sendPort, &message_cobj);
    NSCAssert(success, @"Dart_PostCObject_DL failed.");
  }];
}
