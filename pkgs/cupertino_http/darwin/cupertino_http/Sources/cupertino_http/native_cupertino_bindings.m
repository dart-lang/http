#include <stdint.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSURLCache.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSURLSession.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSProgress.h>
#import <Foundation/NSURLResponse.h>
#import <Foundation/NSHTTPCookieStorage.h>
#import <Foundation/NSOperation.h>
#import <Foundation/NSError.h>
#import <Foundation/NSDictionary.h>
#import "utils.h"

#if !__has_feature(objc_arc)
#error "This file must be compiled with ARC enabled"
#endif

id objc_retain(id);
id objc_retainBlock(id);

@interface _NativeCupertinoHttp_BlockDestroyer : NSObject {}
@property int64_t closure_id;
@property int64_t dispose_port;
@property void (*dtor)(int64_t, int64_t);
- (void)dealloc;
@end
@implementation _NativeCupertinoHttp_BlockDestroyer
- (void)dealloc { self.dtor(self.dispose_port, self.closure_id); }
@end

typedef void  (^_BlockType)();
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_1pl9qdv(
    _BlockType block)  {
  return block();
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType _NativeCupertinoHttp_newClosureBlock_1pl9qdv(
    void  (*trampoline)(id , int64_t ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType weakBlk;
  _BlockType blk = ^void () {
    return trampoline(weakBlk, obj.closure_id);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType _NativeCupertinoHttp_wrapListenerBlock_1pl9qdv(_BlockType block) NS_RETURNS_RETAINED {
  return ^void() {
    objc_retainBlock(block);
    block();
  };
}

typedef void  (^_BlockingTrampoline)(void * waiter);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType _NativeCupertinoHttp_wrapBlockingBlock_1pl9qdv(
    _BlockingTrampoline block, _BlockingTrampoline listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void() {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter);
      awaitWaiter(waiter);
    }
  };
}

typedef int  (^_BlockType1)(void * arg0, void * arg1);
__attribute__((visibility("default"))) __attribute__((used))
int  _NativeCupertinoHttp_invokeBlock_1xo8x7m(
    _BlockType1 block, void * arg0, void * arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType1 _NativeCupertinoHttp_newClosureBlock_1xo8x7m(
    int  (*trampoline)(id , int64_t , void * , void * ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType1 weakBlk;
  _BlockType1 blk = ^int (void * arg0, void * arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

typedef NSComparisonResult  (^_BlockType2)(id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
NSComparisonResult  _NativeCupertinoHttp_invokeBlock_8brfhu(
    _BlockType2 block, id arg0, id arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType2 _NativeCupertinoHttp_newClosureBlock_8brfhu(
    NSComparisonResult  (*trampoline)(id , int64_t , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType2 weakBlk;
  _BlockType2 blk = ^NSComparisonResult (id arg0, id arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

typedef void  (^_BlockType3)(id arg0);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_1jdvcbf(
    _BlockType3 block, id arg0)  {
  return block(arg0);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType3 _NativeCupertinoHttp_newClosureBlock_1jdvcbf(
    void  (*trampoline)(id , int64_t , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType3 weakBlk;
  _BlockType3 blk = ^void (id arg0) {
    return trampoline(weakBlk, obj.closure_id, arg0);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType3 _NativeCupertinoHttp_wrapListenerBlock_1jdvcbf(_BlockType3 block) NS_RETURNS_RETAINED {
  return ^void(id arg0) {
    objc_retainBlock(block);
    block(objc_retain(arg0));
  };
}

typedef void  (^_BlockingTrampoline3)(void * waiter, id arg0);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType3 _NativeCupertinoHttp_wrapBlockingBlock_1jdvcbf(
    _BlockingTrampoline3 block, _BlockingTrampoline3 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0));
      awaitWaiter(waiter);
    }
  };
}

typedef BOOL  (^_BlockType4)(void * arg0);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _NativeCupertinoHttp_invokeBlock_e3qsqz(
    _BlockType4 block, void * arg0)  {
  return block(arg0);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType4 _NativeCupertinoHttp_newClosureBlock_e3qsqz(
    BOOL  (*trampoline)(id , int64_t , void * ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType4 weakBlk;
  _BlockType4 blk = ^BOOL (void * arg0) {
    return trampoline(weakBlk, obj.closure_id, arg0);
  };
  weakBlk = blk;
  return blk;
}

typedef id  (^_BlockType5)(void * arg0);
__attribute__((visibility("default"))) __attribute__((used))
id  _NativeCupertinoHttp_invokeBlock_1yesha9(
    _BlockType5 block, void * arg0)  {
  return block(arg0);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType5 _NativeCupertinoHttp_newClosureBlock_1yesha9(
    id  (*trampoline)(id , int64_t , void * ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType5 weakBlk;
  _BlockType5 blk = ^id (void * arg0) {
    return trampoline(weakBlk, obj.closure_id, arg0);
  };
  weakBlk = blk;
  return blk;
}

typedef void  (^_BlockType6)(void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_wjovn7(
    _BlockType6 block, void * arg0, id arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType6 _NativeCupertinoHttp_newClosureBlock_wjovn7(
    void  (*trampoline)(id , int64_t , void * , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType6 weakBlk;
  _BlockType6 blk = ^void (void * arg0, id arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType6 _NativeCupertinoHttp_wrapListenerBlock_wjovn7(_BlockType6 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^_BlockingTrampoline6)(void * waiter, void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType6 _NativeCupertinoHttp_wrapBlockingBlock_wjovn7(
    _BlockingTrampoline6 block, _BlockingTrampoline6 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1));
      awaitWaiter(waiter);
    }
  };
}

typedef id  (^_BlockType7)(void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
id  _NativeCupertinoHttp_invokeBlock_1m9h2n(
    _BlockType7 block, void * arg0, id arg1) NS_RETURNS_RETAINED {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType7 _NativeCupertinoHttp_newClosureBlock_1m9h2n(
    id  (*trampoline)(id , int64_t , void * , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType7 weakBlk;
  _BlockType7 blk = ^id (void * arg0, id arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

typedef void  (^_BlockType8)(id arg0, id arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_1krhfwz(
    _BlockType8 block, id arg0, id arg1, BOOL * arg2)  {
  return block(arg0, arg1, arg2);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType8 _NativeCupertinoHttp_newClosureBlock_1krhfwz(
    void  (*trampoline)(id , int64_t , id , id , BOOL * ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType8 weakBlk;
  _BlockType8 blk = ^void (id arg0, id arg1, BOOL * arg2) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType8 _NativeCupertinoHttp_wrapListenerBlock_1krhfwz(_BlockType8 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, BOOL * arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), arg2);
  };
}

typedef void  (^_BlockingTrampoline8)(void * waiter, id arg0, id arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType8 _NativeCupertinoHttp_wrapBlockingBlock_1krhfwz(
    _BlockingTrampoline8 block, _BlockingTrampoline8 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, BOOL * arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), objc_retain(arg1), arg2);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), objc_retain(arg1), arg2);
      awaitWaiter(waiter);
    }
  };
}

typedef BOOL  (^_BlockType9)(id arg0, id arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _NativeCupertinoHttp_invokeBlock_gi6iel(
    _BlockType9 block, id arg0, id arg1, BOOL * arg2)  {
  return block(arg0, arg1, arg2);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType9 _NativeCupertinoHttp_newClosureBlock_gi6iel(
    BOOL  (*trampoline)(id , int64_t , id , id , BOOL * ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType9 weakBlk;
  _BlockType9 blk = ^BOOL (id arg0, id arg1, BOOL * arg2) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2);
  };
  weakBlk = blk;
  return blk;
}

typedef unsigned long  (^_BlockType10)(void * arg0, NSFastEnumerationState * arg1, id * arg2, unsigned long arg3);
__attribute__((visibility("default"))) __attribute__((used))
unsigned long  _NativeCupertinoHttp_invokeBlock_17ap02x(
    _BlockType10 block, void * arg0, NSFastEnumerationState * arg1, id * arg2, unsigned long arg3)  {
  return block(arg0, arg1, arg2, arg3);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType10 _NativeCupertinoHttp_newClosureBlock_17ap02x(
    unsigned long  (*trampoline)(id , int64_t , void * , NSFastEnumerationState * , id * , unsigned long ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType10 weakBlk;
  _BlockType10 blk = ^unsigned long (void * arg0, NSFastEnumerationState * arg1, id * arg2, unsigned long arg3) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2, arg3);
  };
  weakBlk = blk;
  return blk;
}

typedef id  (^_BlockType11)(id arg0);
__attribute__((visibility("default"))) __attribute__((used))
id  _NativeCupertinoHttp_invokeBlock_1e364rg(
    _BlockType11 block, id arg0)  {
  return block(arg0);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType11 _NativeCupertinoHttp_newClosureBlock_1e364rg(
    id  (*trampoline)(id , int64_t , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType11 weakBlk;
  _BlockType11 blk = ^id (id arg0) {
    return trampoline(weakBlk, obj.closure_id, arg0);
  };
  weakBlk = blk;
  return blk;
}

typedef void  (^_BlockType12)(struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_tg5tbv(
    _BlockType12 block, struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType12 _NativeCupertinoHttp_newClosureBlock_tg5tbv(
    void  (*trampoline)(id , int64_t , struct __CFRunLoopObserver * , CFRunLoopActivity ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType12 weakBlk;
  _BlockType12 blk = ^void (struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType12 _NativeCupertinoHttp_wrapListenerBlock_tg5tbv(_BlockType12 block) NS_RETURNS_RETAINED {
  return ^void(struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline12)(void * waiter, struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType12 _NativeCupertinoHttp_wrapBlockingBlock_tg5tbv(
    _BlockingTrampoline12 block, _BlockingTrampoline12 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, arg1);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType13)(struct __CFRunLoopTimer * arg0);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_1dqvvol(
    _BlockType13 block, struct __CFRunLoopTimer * arg0)  {
  return block(arg0);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType13 _NativeCupertinoHttp_newClosureBlock_1dqvvol(
    void  (*trampoline)(id , int64_t , struct __CFRunLoopTimer * ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType13 weakBlk;
  _BlockType13 blk = ^void (struct __CFRunLoopTimer * arg0) {
    return trampoline(weakBlk, obj.closure_id, arg0);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType13 _NativeCupertinoHttp_wrapListenerBlock_1dqvvol(_BlockType13 block) NS_RETURNS_RETAINED {
  return ^void(struct __CFRunLoopTimer * arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline13)(void * waiter, struct __CFRunLoopTimer * arg0);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType13 _NativeCupertinoHttp_wrapBlockingBlock_1dqvvol(
    _BlockingTrampoline13 block, _BlockingTrampoline13 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(struct __CFRunLoopTimer * arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType14)(size_t arg0);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_6enxqz(
    _BlockType14 block, size_t arg0)  {
  return block(arg0);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType14 _NativeCupertinoHttp_newClosureBlock_6enxqz(
    void  (*trampoline)(id , int64_t , size_t ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType14 weakBlk;
  _BlockType14 blk = ^void (size_t arg0) {
    return trampoline(weakBlk, obj.closure_id, arg0);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType14 _NativeCupertinoHttp_wrapListenerBlock_6enxqz(_BlockType14 block) NS_RETURNS_RETAINED {
  return ^void(size_t arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline14)(void * waiter, size_t arg0);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType14 _NativeCupertinoHttp_wrapBlockingBlock_6enxqz(
    _BlockingTrampoline14 block, _BlockingTrampoline14 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(size_t arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter);
    }
  };
}

typedef BOOL  (^_BlockType15)(id arg0, size_t arg1, void * arg2, size_t arg3);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _NativeCupertinoHttp_invokeBlock_16886ch(
    _BlockType15 block, id arg0, size_t arg1, void * arg2, size_t arg3)  {
  return block(arg0, arg1, arg2, arg3);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType15 _NativeCupertinoHttp_newClosureBlock_16886ch(
    BOOL  (*trampoline)(id , int64_t , id , size_t , void * , size_t ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType15 weakBlk;
  _BlockType15 blk = ^BOOL (id arg0, size_t arg1, void * arg2, size_t arg3) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2, arg3);
  };
  weakBlk = blk;
  return blk;
}

typedef void  (^_BlockType16)(id arg0, int arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_qxvyq2(
    _BlockType16 block, id arg0, int arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType16 _NativeCupertinoHttp_newClosureBlock_qxvyq2(
    void  (*trampoline)(id , int64_t , id , int ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType16 weakBlk;
  _BlockType16 blk = ^void (id arg0, int arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType16 _NativeCupertinoHttp_wrapListenerBlock_qxvyq2(_BlockType16 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, int arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1);
  };
}

typedef void  (^_BlockingTrampoline16)(void * waiter, id arg0, int arg1);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType16 _NativeCupertinoHttp_wrapBlockingBlock_qxvyq2(
    _BlockingTrampoline16 block, _BlockingTrampoline16 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, int arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), arg1);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType17)(int arg0);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_9o8504(
    _BlockType17 block, int arg0)  {
  return block(arg0);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType17 _NativeCupertinoHttp_newClosureBlock_9o8504(
    void  (*trampoline)(id , int64_t , int ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType17 weakBlk;
  _BlockType17 blk = ^void (int arg0) {
    return trampoline(weakBlk, obj.closure_id, arg0);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType17 _NativeCupertinoHttp_wrapListenerBlock_9o8504(_BlockType17 block) NS_RETURNS_RETAINED {
  return ^void(int arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline17)(void * waiter, int arg0);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType17 _NativeCupertinoHttp_wrapBlockingBlock_9o8504(
    _BlockingTrampoline17 block, _BlockingTrampoline17 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(int arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType18)(BOOL arg0, id arg1, int arg2);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_12a4qua(
    _BlockType18 block, BOOL arg0, id arg1, int arg2)  {
  return block(arg0, arg1, arg2);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType18 _NativeCupertinoHttp_newClosureBlock_12a4qua(
    void  (*trampoline)(id , int64_t , BOOL , id , int ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType18 weakBlk;
  _BlockType18 blk = ^void (BOOL arg0, id arg1, int arg2) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType18 _NativeCupertinoHttp_wrapListenerBlock_12a4qua(_BlockType18 block) NS_RETURNS_RETAINED {
  return ^void(BOOL arg0, id arg1, int arg2) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), arg2);
  };
}

typedef void  (^_BlockingTrampoline18)(void * waiter, BOOL arg0, id arg1, int arg2);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType18 _NativeCupertinoHttp_wrapBlockingBlock_12a4qua(
    _BlockingTrampoline18 block, _BlockingTrampoline18 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(BOOL arg0, id arg1, int arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), arg2);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), arg2);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType19)(struct __SecTrust * arg0, SecTrustResultType arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_gwxhxt(
    _BlockType19 block, struct __SecTrust * arg0, SecTrustResultType arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType19 _NativeCupertinoHttp_newClosureBlock_gwxhxt(
    void  (*trampoline)(id , int64_t , struct __SecTrust * , SecTrustResultType ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType19 weakBlk;
  _BlockType19 blk = ^void (struct __SecTrust * arg0, SecTrustResultType arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType19 _NativeCupertinoHttp_wrapListenerBlock_gwxhxt(_BlockType19 block) NS_RETURNS_RETAINED {
  return ^void(struct __SecTrust * arg0, SecTrustResultType arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline19)(void * waiter, struct __SecTrust * arg0, SecTrustResultType arg1);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType19 _NativeCupertinoHttp_wrapBlockingBlock_gwxhxt(
    _BlockingTrampoline19 block, _BlockingTrampoline19 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(struct __SecTrust * arg0, SecTrustResultType arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, arg1);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType20)(struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_k73ff5(
    _BlockType20 block, struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2)  {
  return block(arg0, arg1, arg2);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType20 _NativeCupertinoHttp_newClosureBlock_k73ff5(
    void  (*trampoline)(id , int64_t , struct __SecTrust * , BOOL , struct __CFError * ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType20 weakBlk;
  _BlockType20 blk = ^void (struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType20 _NativeCupertinoHttp_wrapListenerBlock_k73ff5(_BlockType20 block) NS_RETURNS_RETAINED {
  return ^void(struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2) {
    objc_retainBlock(block);
    block(arg0, arg1, arg2);
  };
}

typedef void  (^_BlockingTrampoline20)(void * waiter, struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType20 _NativeCupertinoHttp_wrapBlockingBlock_k73ff5(
    _BlockingTrampoline20 block, _BlockingTrampoline20 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, arg1, arg2);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, arg1, arg2);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType21)(uint16_t arg0);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_15f11yh(
    _BlockType21 block, uint16_t arg0)  {
  return block(arg0);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType21 _NativeCupertinoHttp_newClosureBlock_15f11yh(
    void  (*trampoline)(id , int64_t , uint16_t ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType21 weakBlk;
  _BlockType21 blk = ^void (uint16_t arg0) {
    return trampoline(weakBlk, obj.closure_id, arg0);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType21 _NativeCupertinoHttp_wrapListenerBlock_15f11yh(_BlockType21 block) NS_RETURNS_RETAINED {
  return ^void(uint16_t arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline21)(void * waiter, uint16_t arg0);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType21 _NativeCupertinoHttp_wrapBlockingBlock_15f11yh(
    _BlockingTrampoline21 block, _BlockingTrampoline21 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(uint16_t arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType22)(id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_wjvic9(
    _BlockType22 block, id arg0, id arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType22 _NativeCupertinoHttp_newClosureBlock_wjvic9(
    void  (*trampoline)(id , int64_t , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType22 weakBlk;
  _BlockType22 blk = ^void (id arg0, id arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType22 _NativeCupertinoHttp_wrapListenerBlock_wjvic9(_BlockType22 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1));
  };
}

typedef void  (^_BlockingTrampoline22)(void * waiter, id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType22 _NativeCupertinoHttp_wrapBlockingBlock_wjvic9(
    _BlockingTrampoline22 block, _BlockingTrampoline22 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), objc_retain(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), objc_retain(arg1));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType23)(id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_91c9gi(
    _BlockType23 block, id arg0, id arg1, id arg2)  {
  return block(arg0, arg1, arg2);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType23 _NativeCupertinoHttp_newClosureBlock_91c9gi(
    void  (*trampoline)(id , int64_t , id , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType23 weakBlk;
  _BlockType23 blk = ^void (id arg0, id arg1, id arg2) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType23 _NativeCupertinoHttp_wrapListenerBlock_91c9gi(_BlockType23 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), objc_retainBlock(arg2));
  };
}

typedef void  (^_BlockingTrampoline23)(void * waiter, id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType23 _NativeCupertinoHttp_wrapBlockingBlock_91c9gi(
    _BlockingTrampoline23 block, _BlockingTrampoline23 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, id arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), objc_retain(arg1), objc_retainBlock(arg2));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), objc_retain(arg1), objc_retainBlock(arg2));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType24)(id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_14pxqbs(
    _BlockType24 block, id arg0, id arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType24 _NativeCupertinoHttp_newClosureBlock_14pxqbs(
    void  (*trampoline)(id , int64_t , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType24 weakBlk;
  _BlockType24 blk = ^void (id arg0, id arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType24 _NativeCupertinoHttp_wrapListenerBlock_14pxqbs(_BlockType24 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retainBlock(arg1));
  };
}

typedef void  (^_BlockingTrampoline24)(void * waiter, id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType24 _NativeCupertinoHttp_wrapBlockingBlock_14pxqbs(
    _BlockingTrampoline24 block, _BlockingTrampoline24 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), objc_retainBlock(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), objc_retainBlock(arg1));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType25)(BOOL arg0);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_1s56lr9(
    _BlockType25 block, BOOL arg0)  {
  return block(arg0);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType25 _NativeCupertinoHttp_newClosureBlock_1s56lr9(
    void  (*trampoline)(id , int64_t , BOOL ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType25 weakBlk;
  _BlockType25 blk = ^void (BOOL arg0) {
    return trampoline(weakBlk, obj.closure_id, arg0);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType25 _NativeCupertinoHttp_wrapListenerBlock_1s56lr9(_BlockType25 block) NS_RETURNS_RETAINED {
  return ^void(BOOL arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline25)(void * waiter, BOOL arg0);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType25 _NativeCupertinoHttp_wrapBlockingBlock_1s56lr9(
    _BlockingTrampoline25 block, _BlockingTrampoline25 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(BOOL arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType26)(id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_1hcfngn(
    _BlockType26 block, id arg0, id arg1, id arg2)  {
  return block(arg0, arg1, arg2);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType26 _NativeCupertinoHttp_newClosureBlock_1hcfngn(
    void  (*trampoline)(id , int64_t , id , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType26 weakBlk;
  _BlockType26 blk = ^void (id arg0, id arg1, id arg2) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType26 _NativeCupertinoHttp_wrapListenerBlock_1hcfngn(_BlockType26 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^_BlockingTrampoline26)(void * waiter, id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType26 _NativeCupertinoHttp_wrapBlockingBlock_1hcfngn(
    _BlockingTrampoline26 block, _BlockingTrampoline26 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, id arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), objc_retain(arg1), objc_retain(arg2));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), objc_retain(arg1), objc_retain(arg2));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType27)(NSURLSessionResponseDisposition arg0);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_16sve1d(
    _BlockType27 block, NSURLSessionResponseDisposition arg0)  {
  return block(arg0);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType27 _NativeCupertinoHttp_newClosureBlock_16sve1d(
    void  (*trampoline)(id , int64_t , NSURLSessionResponseDisposition ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType27 weakBlk;
  _BlockType27 blk = ^void (NSURLSessionResponseDisposition arg0) {
    return trampoline(weakBlk, obj.closure_id, arg0);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType27 _NativeCupertinoHttp_wrapListenerBlock_16sve1d(_BlockType27 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionResponseDisposition arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline27)(void * waiter, NSURLSessionResponseDisposition arg0);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType27 _NativeCupertinoHttp_wrapBlockingBlock_16sve1d(
    _BlockingTrampoline27 block, _BlockingTrampoline27 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(NSURLSessionResponseDisposition arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType28)(NSURLSessionDelayedRequestDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_mn1xu3(
    _BlockType28 block, NSURLSessionDelayedRequestDisposition arg0, id arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType28 _NativeCupertinoHttp_newClosureBlock_mn1xu3(
    void  (*trampoline)(id , int64_t , NSURLSessionDelayedRequestDisposition , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType28 weakBlk;
  _BlockType28 blk = ^void (NSURLSessionDelayedRequestDisposition arg0, id arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType28 _NativeCupertinoHttp_wrapListenerBlock_mn1xu3(_BlockType28 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionDelayedRequestDisposition arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^_BlockingTrampoline28)(void * waiter, NSURLSessionDelayedRequestDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType28 _NativeCupertinoHttp_wrapBlockingBlock_mn1xu3(
    _BlockingTrampoline28 block, _BlockingTrampoline28 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(NSURLSessionDelayedRequestDisposition arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType29)(void * arg0, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_1f43wec(
    _BlockType29 block, void * arg0, id arg1, id arg2, id arg3, id arg4)  {
  return block(arg0, arg1, arg2, arg3, arg4);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType29 _NativeCupertinoHttp_newClosureBlock_1f43wec(
    void  (*trampoline)(id , int64_t , void * , id , id , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType29 weakBlk;
  _BlockType29 blk = ^void (void * arg0, id arg1, id arg2, id arg3, id arg4) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2, arg3, arg4);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType29 _NativeCupertinoHttp_wrapListenerBlock_1f43wec(_BlockType29 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retainBlock(arg4));
  };
}

typedef void  (^_BlockingTrampoline29)(void * waiter, void * arg0, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType29 _NativeCupertinoHttp_wrapBlockingBlock_1f43wec(
    _BlockingTrampoline29 block, _BlockingTrampoline29 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retainBlock(arg4));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retainBlock(arg4));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType30)(void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_1r3kn8f(
    _BlockType30 block, void * arg0, id arg1, id arg2, id arg3)  {
  return block(arg0, arg1, arg2, arg3);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType30 _NativeCupertinoHttp_newClosureBlock_1r3kn8f(
    void  (*trampoline)(id , int64_t , void * , id , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType30 weakBlk;
  _BlockType30 blk = ^void (void * arg0, id arg1, id arg2, id arg3) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2, arg3);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType30 _NativeCupertinoHttp_wrapListenerBlock_1r3kn8f(_BlockType30 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

typedef void  (^_BlockingTrampoline30)(void * waiter, void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType30 _NativeCupertinoHttp_wrapBlockingBlock_1r3kn8f(
    _BlockingTrampoline30 block, _BlockingTrampoline30 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType31)(void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_ao4xm9(
    _BlockType31 block, void * arg0, id arg1, id arg2)  {
  return block(arg0, arg1, arg2);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType31 _NativeCupertinoHttp_newClosureBlock_ao4xm9(
    void  (*trampoline)(id , int64_t , void * , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType31 weakBlk;
  _BlockType31 blk = ^void (void * arg0, id arg1, id arg2) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType31 _NativeCupertinoHttp_wrapListenerBlock_ao4xm9(_BlockType31 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^_BlockingTrampoline31)(void * waiter, void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType31 _NativeCupertinoHttp_wrapBlockingBlock_ao4xm9(
    _BlockingTrampoline31 block, _BlockingTrampoline31 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType32)(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_13vswqm(
    _BlockType32 block, void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5)  {
  return block(arg0, arg1, arg2, arg3, arg4, arg5);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType32 _NativeCupertinoHttp_newClosureBlock_13vswqm(
    void  (*trampoline)(id , int64_t , void * , id , id , id , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType32 weakBlk;
  _BlockType32 blk = ^void (void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2, arg3, arg4, arg5);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType32 _NativeCupertinoHttp_wrapListenerBlock_13vswqm(_BlockType32 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retain(arg4), objc_retainBlock(arg5));
  };
}

typedef void  (^_BlockingTrampoline32)(void * waiter, void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType32 _NativeCupertinoHttp_wrapBlockingBlock_13vswqm(
    _BlockingTrampoline32 block, _BlockingTrampoline32 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retain(arg4), objc_retainBlock(arg5));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retain(arg4), objc_retainBlock(arg5));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType33)(NSURLSessionAuthChallengeDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_37btrl(
    _BlockType33 block, NSURLSessionAuthChallengeDisposition arg0, id arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType33 _NativeCupertinoHttp_newClosureBlock_37btrl(
    void  (*trampoline)(id , int64_t , NSURLSessionAuthChallengeDisposition , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType33 weakBlk;
  _BlockType33 blk = ^void (NSURLSessionAuthChallengeDisposition arg0, id arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType33 _NativeCupertinoHttp_wrapListenerBlock_37btrl(_BlockType33 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionAuthChallengeDisposition arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^_BlockingTrampoline33)(void * waiter, NSURLSessionAuthChallengeDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType33 _NativeCupertinoHttp_wrapBlockingBlock_37btrl(
    _BlockingTrampoline33 block, _BlockingTrampoline33 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(NSURLSessionAuthChallengeDisposition arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType34)(void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_12nszru(
    _BlockType34 block, void * arg0, id arg1, id arg2, id arg3)  {
  return block(arg0, arg1, arg2, arg3);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType34 _NativeCupertinoHttp_newClosureBlock_12nszru(
    void  (*trampoline)(id , int64_t , void * , id , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType34 weakBlk;
  _BlockType34 blk = ^void (void * arg0, id arg1, id arg2, id arg3) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2, arg3);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType34 _NativeCupertinoHttp_wrapListenerBlock_12nszru(_BlockType34 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retainBlock(arg3));
  };
}

typedef void  (^_BlockingTrampoline34)(void * waiter, void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType34 _NativeCupertinoHttp_wrapBlockingBlock_12nszru(
    _BlockingTrampoline34 block, _BlockingTrampoline34 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), objc_retainBlock(arg3));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), objc_retainBlock(arg3));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType35)(void * arg0, id arg1, id arg2, int64_t arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_qm01og(
    _BlockType35 block, void * arg0, id arg1, id arg2, int64_t arg3, id arg4)  {
  return block(arg0, arg1, arg2, arg3, arg4);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType35 _NativeCupertinoHttp_newClosureBlock_qm01og(
    void  (*trampoline)(id , int64_t , void * , id , id , int64_t , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType35 weakBlk;
  _BlockType35 blk = ^void (void * arg0, id arg1, id arg2, int64_t arg3, id arg4) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2, arg3, arg4);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType35 _NativeCupertinoHttp_wrapListenerBlock_qm01og(_BlockType35 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retainBlock(arg4));
  };
}

typedef void  (^_BlockingTrampoline35)(void * waiter, void * arg0, id arg1, id arg2, int64_t arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType35 _NativeCupertinoHttp_wrapBlockingBlock_qm01og(
    _BlockingTrampoline35 block, _BlockingTrampoline35 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, id arg4) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retainBlock(arg4));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retainBlock(arg4));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType36)(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_1uuez7b(
    _BlockType36 block, void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5)  {
  return block(arg0, arg1, arg2, arg3, arg4, arg5);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType36 _NativeCupertinoHttp_newClosureBlock_1uuez7b(
    void  (*trampoline)(id , int64_t , void * , id , id , int64_t , int64_t , int64_t ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType36 weakBlk;
  _BlockType36 blk = ^void (void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2, arg3, arg4, arg5);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType36 _NativeCupertinoHttp_wrapListenerBlock_1uuez7b(_BlockType36 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4, arg5);
  };
}

typedef void  (^_BlockingTrampoline36)(void * waiter, void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType36 _NativeCupertinoHttp_wrapBlockingBlock_1uuez7b(
    _BlockingTrampoline36 block, _BlockingTrampoline36 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4, arg5);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4, arg5);
      awaitWaiter(waiter);
    }
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionDataDelegate(void) { return @protocol(NSURLSessionDataDelegate); }

typedef void  (^_BlockType37)(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_9qxjkl(
    _BlockType37 block, void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4)  {
  return block(arg0, arg1, arg2, arg3, arg4);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType37 _NativeCupertinoHttp_newClosureBlock_9qxjkl(
    void  (*trampoline)(id , int64_t , void * , id , id , int64_t , int64_t ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType37 weakBlk;
  _BlockType37 blk = ^void (void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2, arg3, arg4);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType37 _NativeCupertinoHttp_wrapListenerBlock_9qxjkl(_BlockType37 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4);
  };
}

typedef void  (^_BlockingTrampoline37)(void * waiter, void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType37 _NativeCupertinoHttp_wrapBlockingBlock_9qxjkl(
    _BlockingTrampoline37 block, _BlockingTrampoline37 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4);
      awaitWaiter(waiter);
    }
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionDownloadDelegate(void) { return @protocol(NSURLSessionDownloadDelegate); }

typedef void  (^_BlockType38)(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_3lo3bb(
    _BlockType38 block, void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4)  {
  return block(arg0, arg1, arg2, arg3, arg4);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType38 _NativeCupertinoHttp_newClosureBlock_3lo3bb(
    void  (*trampoline)(id , int64_t , void * , id , id , NSURLSessionWebSocketCloseCode , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType38 weakBlk;
  _BlockType38 blk = ^void (void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2, arg3, arg4);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType38 _NativeCupertinoHttp_wrapListenerBlock_3lo3bb(_BlockType38 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retain(arg4));
  };
}

typedef void  (^_BlockingTrampoline38)(void * waiter, void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType38 _NativeCupertinoHttp_wrapBlockingBlock_3lo3bb(
    _BlockingTrampoline38 block, _BlockingTrampoline38 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retain(arg4));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retain(arg4));
      awaitWaiter(waiter);
    }
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionWebSocketDelegate(void) { return @protocol(NSURLSessionWebSocketDelegate); }

typedef void  (^_BlockType39)(id arg0, unsigned long arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_16ko9u(
    _BlockType39 block, id arg0, unsigned long arg1, BOOL * arg2)  {
  return block(arg0, arg1, arg2);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType39 _NativeCupertinoHttp_newClosureBlock_16ko9u(
    void  (*trampoline)(id , int64_t , id , unsigned long , BOOL * ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType39 weakBlk;
  _BlockType39 blk = ^void (id arg0, unsigned long arg1, BOOL * arg2) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType39 _NativeCupertinoHttp_wrapListenerBlock_16ko9u(_BlockType39 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, unsigned long arg1, BOOL * arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1, arg2);
  };
}

typedef void  (^_BlockingTrampoline39)(void * waiter, id arg0, unsigned long arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType39 _NativeCupertinoHttp_wrapBlockingBlock_16ko9u(
    _BlockingTrampoline39 block, _BlockingTrampoline39 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, unsigned long arg1, BOOL * arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), arg1, arg2);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), arg1, arg2);
      awaitWaiter(waiter);
    }
  };
}

typedef BOOL  (^_BlockType40)(id arg0, unsigned long arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _NativeCupertinoHttp_invokeBlock_kujo9w(
    _BlockType40 block, id arg0, unsigned long arg1, BOOL * arg2)  {
  return block(arg0, arg1, arg2);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType40 _NativeCupertinoHttp_newClosureBlock_kujo9w(
    BOOL  (*trampoline)(id , int64_t , id , unsigned long , BOOL * ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType40 weakBlk;
  _BlockType40 blk = ^BOOL (id arg0, unsigned long arg1, BOOL * arg2) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2);
  };
  weakBlk = blk;
  return blk;
}

typedef BOOL  (^_BlockType41)(id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _NativeCupertinoHttp_invokeBlock_1lqxdg3(
    _BlockType41 block, id arg0, id arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType41 _NativeCupertinoHttp_newClosureBlock_1lqxdg3(
    BOOL  (*trampoline)(id , int64_t , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType41 weakBlk;
  _BlockType41 blk = ^BOOL (id arg0, id arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

typedef void  (^_BlockType42)(id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_1j2nt86(
    _BlockType42 block, id arg0, id arg1, id arg2)  {
  return block(arg0, arg1, arg2);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType42 _NativeCupertinoHttp_newClosureBlock_1j2nt86(
    void  (*trampoline)(id , int64_t , id , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType42 weakBlk;
  _BlockType42 blk = ^void (id arg0, id arg1, id arg2) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType42 _NativeCupertinoHttp_wrapListenerBlock_1j2nt86(_BlockType42 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retainBlock(arg0), objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^_BlockingTrampoline42)(void * waiter, id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType42 _NativeCupertinoHttp_wrapBlockingBlock_1j2nt86(
    _BlockingTrampoline42 block, _BlockingTrampoline42 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, id arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retainBlock(arg0), objc_retain(arg1), objc_retain(arg2));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retainBlock(arg0), objc_retain(arg1), objc_retain(arg2));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType43)(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_8wbg7l(
    _BlockType43 block, id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3)  {
  return block(arg0, arg1, arg2, arg3);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType43 _NativeCupertinoHttp_newClosureBlock_8wbg7l(
    void  (*trampoline)(id , int64_t , id , struct _NSRange , struct _NSRange , BOOL * ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType43 weakBlk;
  _BlockType43 blk = ^void (id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2, arg3);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType43 _NativeCupertinoHttp_wrapListenerBlock_8wbg7l(_BlockType43 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1, arg2, arg3);
  };
}

typedef void  (^_BlockingTrampoline43)(void * waiter, id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType43 _NativeCupertinoHttp_wrapBlockingBlock_8wbg7l(
    _BlockingTrampoline43 block, _BlockingTrampoline43 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), arg1, arg2, arg3);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), arg1, arg2, arg3);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType44)(id arg0, BOOL * arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_148br51(
    _BlockType44 block, id arg0, BOOL * arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType44 _NativeCupertinoHttp_newClosureBlock_148br51(
    void  (*trampoline)(id , int64_t , id , BOOL * ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType44 weakBlk;
  _BlockType44 blk = ^void (id arg0, BOOL * arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType44 _NativeCupertinoHttp_wrapListenerBlock_148br51(_BlockType44 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, BOOL * arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1);
  };
}

typedef void  (^_BlockingTrampoline44)(void * waiter, id arg0, BOOL * arg1);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType44 _NativeCupertinoHttp_wrapBlockingBlock_148br51(
    _BlockingTrampoline44 block, _BlockingTrampoline44 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, BOOL * arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), arg1);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType45)(unsigned short * arg0, unsigned long arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_vhbh5h(
    _BlockType45 block, unsigned short * arg0, unsigned long arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType45 _NativeCupertinoHttp_newClosureBlock_vhbh5h(
    void  (*trampoline)(id , int64_t , unsigned short * , unsigned long ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType45 weakBlk;
  _BlockType45 blk = ^void (unsigned short * arg0, unsigned long arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType45 _NativeCupertinoHttp_wrapListenerBlock_vhbh5h(_BlockType45 block) NS_RETURNS_RETAINED {
  return ^void(unsigned short * arg0, unsigned long arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline45)(void * waiter, unsigned short * arg0, unsigned long arg1);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType45 _NativeCupertinoHttp_wrapBlockingBlock_vhbh5h(
    _BlockingTrampoline45 block, _BlockingTrampoline45 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(unsigned short * arg0, unsigned long arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, arg1);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType46)(void * arg0, unsigned long arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_zuf90e(
    _BlockType46 block, void * arg0, unsigned long arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType46 _NativeCupertinoHttp_newClosureBlock_zuf90e(
    void  (*trampoline)(id , int64_t , void * , unsigned long ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType46 weakBlk;
  _BlockType46 blk = ^void (void * arg0, unsigned long arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType46 _NativeCupertinoHttp_wrapListenerBlock_zuf90e(_BlockType46 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, unsigned long arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline46)(void * waiter, void * arg0, unsigned long arg1);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType46 _NativeCupertinoHttp_wrapBlockingBlock_zuf90e(
    _BlockingTrampoline46 block, _BlockingTrampoline46 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, unsigned long arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, arg1);
      awaitWaiter(waiter);
    }
  };
}

typedef id  (^_BlockType47)(void * arg0, id arg1, id arg2, id * arg3);
__attribute__((visibility("default"))) __attribute__((used))
id  _NativeCupertinoHttp_invokeBlock_e2pkq8(
    _BlockType47 block, void * arg0, id arg1, id arg2, id * arg3)  {
  return block(arg0, arg1, arg2, arg3);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType47 _NativeCupertinoHttp_newClosureBlock_e2pkq8(
    id  (*trampoline)(id , int64_t , void * , id , id , id * ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType47 weakBlk;
  _BlockType47 blk = ^id (void * arg0, id arg1, id arg2, id * arg3) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2, arg3);
  };
  weakBlk = blk;
  return blk;
}

typedef NSItemProviderRepresentationVisibility  (^_BlockType48)(void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
NSItemProviderRepresentationVisibility  _NativeCupertinoHttp_invokeBlock_1d5d8wd(
    _BlockType48 block, void * arg0, id arg1)  {
  return block(arg0, arg1);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType48 _NativeCupertinoHttp_newClosureBlock_1d5d8wd(
    NSItemProviderRepresentationVisibility  (*trampoline)(id , int64_t , void * , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType48 weakBlk;
  _BlockType48 blk = ^NSItemProviderRepresentationVisibility (void * arg0, id arg1) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1);
  };
  weakBlk = blk;
  return blk;
}

typedef id  (^_BlockType49)(void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
id  _NativeCupertinoHttp_invokeBlock_4saw50(
    _BlockType49 block, void * arg0, id arg1, id arg2)  {
  return block(arg0, arg1, arg2);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType49 _NativeCupertinoHttp_newClosureBlock_4saw50(
    id  (*trampoline)(id , int64_t , void * , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType49 weakBlk;
  _BlockType49 blk = ^id (void * arg0, id arg1, id arg2) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2);
  };
  weakBlk = blk;
  return blk;
}

typedef void  (^_BlockType50)(void * arg0);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_ovsamd(
    _BlockType50 block, void * arg0)  {
  return block(arg0);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType50 _NativeCupertinoHttp_newClosureBlock_ovsamd(
    void  (*trampoline)(id , int64_t , void * ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType50 weakBlk;
  _BlockType50 blk = ^void (void * arg0) {
    return trampoline(weakBlk, obj.closure_id, arg0);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType50 _NativeCupertinoHttp_wrapListenerBlock_ovsamd(_BlockType50 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline50)(void * waiter, void * arg0);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType50 _NativeCupertinoHttp_wrapBlockingBlock_ovsamd(
    _BlockingTrampoline50 block, _BlockingTrampoline50 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_BlockType51)(id arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeCupertinoHttp_invokeBlock_4ya7yd(
    _BlockType51 block, id arg0, id arg1, id arg2, id arg3)  {
  return block(arg0, arg1, arg2, arg3);
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType51 _NativeCupertinoHttp_newClosureBlock_4ya7yd(
    void  (*trampoline)(id , int64_t , id , id , id , id ), int64_t closure_id, int64_t dispose_port,
    void (*dtor)(int64_t, int64_t)) NS_RETURNS_RETAINED {
  _NativeCupertinoHttp_BlockDestroyer* obj = [[_NativeCupertinoHttp_BlockDestroyer alloc] init];
  obj.closure_id = closure_id;
  obj.dispose_port = dispose_port;
  obj.dtor = dtor;
  __weak __block _BlockType51 weakBlk;
  _BlockType51 blk = ^void (id arg0, id arg1, id arg2, id arg3) {
    return trampoline(weakBlk, obj.closure_id, arg0, arg1, arg2, arg3);
  };
  weakBlk = blk;
  return blk;
}

__attribute__((visibility("default"))) __attribute__((used))
_BlockType51 _NativeCupertinoHttp_wrapListenerBlock_4ya7yd(_BlockType51 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

typedef void  (^_BlockingTrampoline51)(void * waiter, id arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_BlockType51 _NativeCupertinoHttp_wrapBlockingBlock_4ya7yd(
    _BlockingTrampoline51 block, _BlockingTrampoline51 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, id arg2, id arg3) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
      awaitWaiter(waiter);
    }
  };
}
