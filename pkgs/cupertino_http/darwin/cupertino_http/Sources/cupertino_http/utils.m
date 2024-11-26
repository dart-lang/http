#import <Foundation/NSLock.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSURLSession.h>
#include <stdint.h>

#if !__has_feature(objc_arc)
#error "This file must be compiled with ARC enabled"
#endif

typedef void (^_DidFinish)(void *closure, NSURLSession *session,
                           NSURLSessionDownloadTask *downloadTask,
                           NSURL *location);
typedef void (^_DidFinishWithLock)(NSCondition *lock, NSURLSession *session,
                                   NSURLSessionDownloadTask *downloadTask,
                                   NSURL *location);

__attribute__((visibility("default"))) __attribute__((used)) _DidFinish
adaptFinishWithLock(_DidFinishWithLock block) {
  return ^void(void *closure, NSURLSession *session,
               NSURLSessionDownloadTask *downloadTask, NSURL *location) {
    NSCondition *lock = [[NSCondition alloc] init];
    [lock lock];
    block(lock, session, downloadTask, location);
    [lock lock];
    [lock unlock];
  };
}
