#import "utils.h"

_DidFinish adaptFinishWithLock(_DidFinishWithLock block) {
  return ^void(void *, NSURLSession *session,
               NSURLSessionDownloadTask *downloadTask, NSURL *location) {
    NSCondition *lock = [[NSCondition alloc] init];
    [lock lock];
    block(lock, session, downloadTask, location);
    [lock lock];
    [lock unlock];
  };
}

void doNotCall() {
  // TODO(https://github.com/dart-lang/native/issues/1672): Remove
  // when fixed.
  // Force the protocol information to be available at runtime.
  @protocol (NSURLSessionDataDelegate);
  @protocol (NSURLSessionDownloadDelegate);
  @protocol (NSURLSessionWebSocketDelegate);
}
