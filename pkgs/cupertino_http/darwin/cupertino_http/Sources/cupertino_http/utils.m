#import "utils.h"

_DidFinish adaptFinishWithLock(_DidFinishWithLock block) {
  return ^void(void *closure, NSURLSession *session,
               NSURLSessionDownloadTask *downloadTask, NSURL *location) {
    NSCondition *lock = [[NSCondition alloc] init];
    [lock lock];
    block(lock, session, downloadTask, location);
    [lock lock];
    [lock unlock];
  };
}
