#import <Foundation/NSLock.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSURLSession.h>
#include <stdint.h>

#if !__has_feature(objc_arc)
#error "This file must be compiled with ARC enabled"
#endif

typedef void (^_DidFinish)(void *, NSURLSession *session,
                           NSURLSessionDownloadTask *downloadTask,
                           NSURL *location);
typedef void (^_DidFinishWithLock)(NSCondition *lock, NSURLSession *session,
                                   NSURLSessionDownloadTask *downloadTask,
                                   NSURL *location);
/// Create a block useable as a
/// `URLSession:downloadTask:didFinishDownloadingToURL:` that can be used to
/// make an async Dart callback behave synchronously.
_DidFinish adaptFinishWithLock(_DidFinishWithLock block);

void doNotCall() {
  // TODO(https://github.com/dart-lang/native/issues/1672): Remove
  // when fixed.
  // Force the protocol information to be available at runtime.
  @protocol (NSURLSessionDataDelegate);
  @protocol (NSURLSessionDownloadDelegate);
  @protocol (NSURLSessionWebSocketDelegate);
}