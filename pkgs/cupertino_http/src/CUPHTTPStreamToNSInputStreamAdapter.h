// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Normally, we'd "import <Foundation/Foundation.h>"
// but that would mean that ffigen would process every file in the Foundation
// framework, which is huge. So just import the headers that we need.
#import <Foundation/NSObject.h>
#import <Foundation/NSStream.h>

#include "dart-sdk/include/dart_api_dl.h"


/**
 * The configuration associated with a NSURLSessionTask.
 * See CUPHTTPClientDelegate.
 */
@interface CUPHTTPStreamToNSInputStreamAdapter : NSInputStream <NSStreamDelegate>

- (instancetype) initWithPort:(Dart_Port)sendPort;
- (NSUInteger) addData:(NSData *) data;
- (void) setDone;
- (void) setError:(NSError *) error;

@end
