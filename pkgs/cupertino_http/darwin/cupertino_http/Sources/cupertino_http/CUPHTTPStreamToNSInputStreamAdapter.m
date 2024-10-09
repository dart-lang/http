// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#import "CUPHTTPStreamToNSInputStreamAdapter.h"

#import <Foundation/Foundation.h>
#include <os/log.h>

@implementation CUPHTTPStreamToNSInputStreamAdapter {
  Dart_Port _sendPort;
  NSCondition* _dataCondition;
  NSMutableData * _data;
  NSStreamStatus _status;
  BOOL _done;
  NSError* _error;
  id<NSStreamDelegate> _delegate;  // This is a weak reference.
}

- (instancetype)initWithPort:(Dart_Port)sendPort {
  self = [super init];
  if (self != nil) {
    _sendPort = sendPort;
    _dataCondition = [[NSCondition alloc] init];
    _data = [[NSMutableData alloc] init];
    _done = NO;
    _status = NSStreamStatusNotOpen;
    _error = nil;
    _delegate = self;
  }
  return self;
}

- (void)dealloc {
  [_dataCondition release];
  [_data release];
  [_error release];
  [super dealloc];
}

- (NSUInteger)addData:(NSData *)data {
  [_dataCondition lock];
  [_data appendData: data];
  [_dataCondition broadcast];
  [_dataCondition unlock];
  return [_data length];
}

- (void)setDone {
  [_dataCondition lock];
  _done = YES;
  [_dataCondition broadcast];
  [_dataCondition unlock];
}

- (void)setError:(NSError *)error {
  [_dataCondition lock];
  [_error release];
  _error = [error retain];
  _status = NSStreamStatusError;
  [_dataCondition broadcast];
  [_dataCondition unlock];
}


#pragma mark - NSStream

- (void)scheduleInRunLoop:(NSRunLoop*)runLoop forMode:(NSString*)mode {
}

- (void)removeFromRunLoop:(NSRunLoop*)runLoop forMode:(NSString*)mode {
}

- (void)open {
  [_dataCondition lock];
  _status = NSStreamStatusOpen;
  [_dataCondition unlock];
}

- (void)close {
  [_dataCondition lock];
  _status = NSStreamStatusClosed;
  [_dataCondition unlock];
}

- (id)propertyForKey:(NSStreamPropertyKey)key {
  return nil;
}

- (BOOL)setProperty:(id)property forKey:(NSStreamPropertyKey)key {
  return NO;
}

- (id<NSStreamDelegate>)delegate {
  return _delegate;
}

- (void)setDelegate:(id<NSStreamDelegate>)delegate {
  if (delegate == nil) {
    _delegate = self;
  } else {
    _delegate = delegate;
  }
}

- (NSError*)streamError {
  return _error;
}

- (NSStreamStatus)streamStatus {
  return _status;
}

#pragma mark - NSInputStream

- (NSInteger)read:(uint8_t*)buffer maxLength:(NSUInteger)len {
  os_log_with_type(OS_LOG_DEFAULT,
                   OS_LOG_TYPE_DEBUG,
                   "CUPHTTPStreamToNSInputStreamAdapter: read len=%tu", len);
  [_dataCondition lock];

  while ([_data length] == 0 && !_done && _error == nil) {
    // There is no data to return so signal the Dart code that it should add more data through
    // [self addData:].
    Dart_CObject message_cobj;
    message_cobj.type = Dart_CObject_kInt64;
    message_cobj.value.as_int64 = len;

    const bool success = Dart_PostCObject_DL(_sendPort, &message_cobj);
    NSCAssert(success, @"Dart_PostCObject_DL failed.");

    [_dataCondition wait];
  }

  NSInteger copySize;
  if (_error == nil) {
    copySize = MIN(len, [_data length]);
    NSRange readRange = NSMakeRange(0, copySize);
    [_data getBytes:(void *)buffer range: readRange];
    // Shift the remaining data over to the beginning of the buffer.
    [_data replaceBytesInRange: readRange withBytes: NULL length: 0];

    if (_done && [_data length] == 0) {
      _status = NSStreamStatusAtEnd;
    }
  } else {
    copySize = -1;
  }

  [_dataCondition unlock];
  return copySize;
}

- (BOOL)getBuffer:(uint8_t**)buffer length:(NSUInteger*)len {
  return NO;
}

- (BOOL)hasBytesAvailable {
  return YES;
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
  id<NSStreamDelegate> delegate = _delegate;
  if (delegate != self) {
    os_log_with_type(OS_LOG_DEFAULT,
                     OS_LOG_TYPE_ERROR,
                     "CUPHTTPStreamToNSInputStreamAdapter: non-self delegate was invoked");
  }
}

@end
