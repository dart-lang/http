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

typedef void  (^_ListenerTrampoline)();
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline _NativeCupertinoHttp_wrapListenerBlock_1pl9qdv(_ListenerTrampoline block) NS_RETURNS_RETAINED {
  return ^void() {
    objc_retainBlock(block);
    block();
  };
}

typedef void  (^_BlockingTrampoline)(void * waiter);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline _NativeCupertinoHttp_wrapBlockingBlock_1pl9qdv(
    _BlockingTrampoline block, _BlockingTrampoline listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void() {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline1)(id arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline1 _NativeCupertinoHttp_wrapListenerBlock_1jdvcbf(_ListenerTrampoline1 block) NS_RETURNS_RETAINED {
  return ^void(id arg0) {
    objc_retainBlock(block);
    block(objc_retain(arg0));
  };
}

typedef void  (^_BlockingTrampoline1)(void * waiter, id arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline1 _NativeCupertinoHttp_wrapBlockingBlock_1jdvcbf(
    _BlockingTrampoline1 block, _BlockingTrampoline1 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline2)(void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline2 _NativeCupertinoHttp_wrapListenerBlock_wjovn7(_ListenerTrampoline2 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^_BlockingTrampoline2)(void * waiter, void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline2 _NativeCupertinoHttp_wrapBlockingBlock_wjovn7(
    _BlockingTrampoline2 block, _BlockingTrampoline2 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline3)(id arg0, id arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline3 _NativeCupertinoHttp_wrapListenerBlock_1krhfwz(_ListenerTrampoline3 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, BOOL * arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), arg2);
  };
}

typedef void  (^_BlockingTrampoline3)(void * waiter, id arg0, id arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline3 _NativeCupertinoHttp_wrapBlockingBlock_1krhfwz(
    _BlockingTrampoline3 block, _BlockingTrampoline3 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, BOOL * arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), objc_retain(arg1), arg2);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), objc_retain(arg1), arg2);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline4)(struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline4 _NativeCupertinoHttp_wrapListenerBlock_tg5tbv(_ListenerTrampoline4 block) NS_RETURNS_RETAINED {
  return ^void(struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline4)(void * waiter, struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline4 _NativeCupertinoHttp_wrapBlockingBlock_tg5tbv(
    _BlockingTrampoline4 block, _BlockingTrampoline4 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, arg1);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline5)(struct __CFRunLoopTimer * arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline5 _NativeCupertinoHttp_wrapListenerBlock_1dqvvol(_ListenerTrampoline5 block) NS_RETURNS_RETAINED {
  return ^void(struct __CFRunLoopTimer * arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline5)(void * waiter, struct __CFRunLoopTimer * arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline5 _NativeCupertinoHttp_wrapBlockingBlock_1dqvvol(
    _BlockingTrampoline5 block, _BlockingTrampoline5 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(struct __CFRunLoopTimer * arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline6)(size_t arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline6 _NativeCupertinoHttp_wrapListenerBlock_6enxqz(_ListenerTrampoline6 block) NS_RETURNS_RETAINED {
  return ^void(size_t arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline6)(void * waiter, size_t arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline6 _NativeCupertinoHttp_wrapBlockingBlock_6enxqz(
    _BlockingTrampoline6 block, _BlockingTrampoline6 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(size_t arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline7)(id arg0, int arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline7 _NativeCupertinoHttp_wrapListenerBlock_qxvyq2(_ListenerTrampoline7 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, int arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1);
  };
}

typedef void  (^_BlockingTrampoline7)(void * waiter, id arg0, int arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline7 _NativeCupertinoHttp_wrapBlockingBlock_qxvyq2(
    _BlockingTrampoline7 block, _BlockingTrampoline7 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, int arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), arg1);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline8)(int arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline8 _NativeCupertinoHttp_wrapListenerBlock_9o8504(_ListenerTrampoline8 block) NS_RETURNS_RETAINED {
  return ^void(int arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline8)(void * waiter, int arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline8 _NativeCupertinoHttp_wrapBlockingBlock_9o8504(
    _BlockingTrampoline8 block, _BlockingTrampoline8 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(int arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline9)(BOOL arg0, id arg1, int arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline9 _NativeCupertinoHttp_wrapListenerBlock_12a4qua(_ListenerTrampoline9 block) NS_RETURNS_RETAINED {
  return ^void(BOOL arg0, id arg1, int arg2) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), arg2);
  };
}

typedef void  (^_BlockingTrampoline9)(void * waiter, BOOL arg0, id arg1, int arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline9 _NativeCupertinoHttp_wrapBlockingBlock_12a4qua(
    _BlockingTrampoline9 block, _BlockingTrampoline9 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(BOOL arg0, id arg1, int arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), arg2);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), arg2);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline10)(struct __SecTrust * arg0, SecTrustResultType arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline10 _NativeCupertinoHttp_wrapListenerBlock_gwxhxt(_ListenerTrampoline10 block) NS_RETURNS_RETAINED {
  return ^void(struct __SecTrust * arg0, SecTrustResultType arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline10)(void * waiter, struct __SecTrust * arg0, SecTrustResultType arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline10 _NativeCupertinoHttp_wrapBlockingBlock_gwxhxt(
    _BlockingTrampoline10 block, _BlockingTrampoline10 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(struct __SecTrust * arg0, SecTrustResultType arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, arg1);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline11)(struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline11 _NativeCupertinoHttp_wrapListenerBlock_k73ff5(_ListenerTrampoline11 block) NS_RETURNS_RETAINED {
  return ^void(struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2) {
    objc_retainBlock(block);
    block(arg0, arg1, arg2);
  };
}

typedef void  (^_BlockingTrampoline11)(void * waiter, struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline11 _NativeCupertinoHttp_wrapBlockingBlock_k73ff5(
    _BlockingTrampoline11 block, _BlockingTrampoline11 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, arg1, arg2);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, arg1, arg2);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline12)(uint16_t arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline12 _NativeCupertinoHttp_wrapListenerBlock_15f11yh(_ListenerTrampoline12 block) NS_RETURNS_RETAINED {
  return ^void(uint16_t arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline12)(void * waiter, uint16_t arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline12 _NativeCupertinoHttp_wrapBlockingBlock_15f11yh(
    _BlockingTrampoline12 block, _BlockingTrampoline12 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(uint16_t arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline13)(id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline13 _NativeCupertinoHttp_wrapListenerBlock_wjvic9(_ListenerTrampoline13 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1));
  };
}

typedef void  (^_BlockingTrampoline13)(void * waiter, id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline13 _NativeCupertinoHttp_wrapBlockingBlock_wjvic9(
    _BlockingTrampoline13 block, _BlockingTrampoline13 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), objc_retain(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), objc_retain(arg1));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline14)(id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline14 _NativeCupertinoHttp_wrapListenerBlock_91c9gi(_ListenerTrampoline14 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), objc_retainBlock(arg2));
  };
}

typedef void  (^_BlockingTrampoline14)(void * waiter, id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline14 _NativeCupertinoHttp_wrapBlockingBlock_91c9gi(
    _BlockingTrampoline14 block, _BlockingTrampoline14 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, id arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), objc_retain(arg1), objc_retainBlock(arg2));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), objc_retain(arg1), objc_retainBlock(arg2));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline15)(id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline15 _NativeCupertinoHttp_wrapListenerBlock_14pxqbs(_ListenerTrampoline15 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retainBlock(arg1));
  };
}

typedef void  (^_BlockingTrampoline15)(void * waiter, id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline15 _NativeCupertinoHttp_wrapBlockingBlock_14pxqbs(
    _BlockingTrampoline15 block, _BlockingTrampoline15 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), objc_retainBlock(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), objc_retainBlock(arg1));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline16)(BOOL arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline16 _NativeCupertinoHttp_wrapListenerBlock_1s56lr9(_ListenerTrampoline16 block) NS_RETURNS_RETAINED {
  return ^void(BOOL arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline16)(void * waiter, BOOL arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline16 _NativeCupertinoHttp_wrapBlockingBlock_1s56lr9(
    _BlockingTrampoline16 block, _BlockingTrampoline16 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(BOOL arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline17)(id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline17 _NativeCupertinoHttp_wrapListenerBlock_1hcfngn(_ListenerTrampoline17 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^_BlockingTrampoline17)(void * waiter, id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline17 _NativeCupertinoHttp_wrapBlockingBlock_1hcfngn(
    _BlockingTrampoline17 block, _BlockingTrampoline17 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, id arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), objc_retain(arg1), objc_retain(arg2));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), objc_retain(arg1), objc_retain(arg2));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline18)(NSURLSessionResponseDisposition arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline18 _NativeCupertinoHttp_wrapListenerBlock_16sve1d(_ListenerTrampoline18 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionResponseDisposition arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline18)(void * waiter, NSURLSessionResponseDisposition arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline18 _NativeCupertinoHttp_wrapBlockingBlock_16sve1d(
    _BlockingTrampoline18 block, _BlockingTrampoline18 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(NSURLSessionResponseDisposition arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline19)(void * arg0, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline19 _NativeCupertinoHttp_wrapListenerBlock_1f43wec(_ListenerTrampoline19 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retainBlock(arg4));
  };
}

typedef void  (^_BlockingTrampoline19)(void * waiter, void * arg0, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline19 _NativeCupertinoHttp_wrapBlockingBlock_1f43wec(
    _BlockingTrampoline19 block, _BlockingTrampoline19 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retainBlock(arg4));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retainBlock(arg4));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline20)(void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline20 _NativeCupertinoHttp_wrapListenerBlock_1r3kn8f(_ListenerTrampoline20 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

typedef void  (^_BlockingTrampoline20)(void * waiter, void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline20 _NativeCupertinoHttp_wrapBlockingBlock_1r3kn8f(
    _BlockingTrampoline20 block, _BlockingTrampoline20 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline21)(void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline21 _NativeCupertinoHttp_wrapListenerBlock_ao4xm9(_ListenerTrampoline21 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^_BlockingTrampoline21)(void * waiter, void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline21 _NativeCupertinoHttp_wrapBlockingBlock_ao4xm9(
    _BlockingTrampoline21 block, _BlockingTrampoline21 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline22)(NSURLSessionDelayedRequestDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline22 _NativeCupertinoHttp_wrapListenerBlock_mn1xu3(_ListenerTrampoline22 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionDelayedRequestDisposition arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^_BlockingTrampoline22)(void * waiter, NSURLSessionDelayedRequestDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline22 _NativeCupertinoHttp_wrapBlockingBlock_mn1xu3(
    _BlockingTrampoline22 block, _BlockingTrampoline22 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(NSURLSessionDelayedRequestDisposition arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline23)(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline23 _NativeCupertinoHttp_wrapListenerBlock_13vswqm(_ListenerTrampoline23 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retain(arg4), objc_retainBlock(arg5));
  };
}

typedef void  (^_BlockingTrampoline23)(void * waiter, void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline23 _NativeCupertinoHttp_wrapBlockingBlock_13vswqm(
    _BlockingTrampoline23 block, _BlockingTrampoline23 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retain(arg4), objc_retainBlock(arg5));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retain(arg4), objc_retainBlock(arg5));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline24)(NSURLSessionAuthChallengeDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline24 _NativeCupertinoHttp_wrapListenerBlock_37btrl(_ListenerTrampoline24 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionAuthChallengeDisposition arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^_BlockingTrampoline24)(void * waiter, NSURLSessionAuthChallengeDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline24 _NativeCupertinoHttp_wrapBlockingBlock_37btrl(
    _BlockingTrampoline24 block, _BlockingTrampoline24 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(NSURLSessionAuthChallengeDisposition arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline25)(void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline25 _NativeCupertinoHttp_wrapListenerBlock_12nszru(_ListenerTrampoline25 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retainBlock(arg3));
  };
}

typedef void  (^_BlockingTrampoline25)(void * waiter, void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline25 _NativeCupertinoHttp_wrapBlockingBlock_12nszru(
    _BlockingTrampoline25 block, _BlockingTrampoline25 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), objc_retainBlock(arg3));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), objc_retainBlock(arg3));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline26)(void * arg0, id arg1, id arg2, int64_t arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline26 _NativeCupertinoHttp_wrapListenerBlock_qm01og(_ListenerTrampoline26 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retainBlock(arg4));
  };
}

typedef void  (^_BlockingTrampoline26)(void * waiter, void * arg0, id arg1, id arg2, int64_t arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline26 _NativeCupertinoHttp_wrapBlockingBlock_qm01og(
    _BlockingTrampoline26 block, _BlockingTrampoline26 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, id arg4) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retainBlock(arg4));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retainBlock(arg4));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline27)(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline27 _NativeCupertinoHttp_wrapListenerBlock_1uuez7b(_ListenerTrampoline27 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4, arg5);
  };
}

typedef void  (^_BlockingTrampoline27)(void * waiter, void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline27 _NativeCupertinoHttp_wrapBlockingBlock_1uuez7b(
    _BlockingTrampoline27 block, _BlockingTrampoline27 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4, arg5);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4, arg5);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionDataDelegate() { return @protocol(NSURLSessionDataDelegate); }

typedef void  (^_ListenerTrampoline28)(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline28 _NativeCupertinoHttp_wrapListenerBlock_9qxjkl(_ListenerTrampoline28 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4);
  };
}

typedef void  (^_BlockingTrampoline28)(void * waiter, void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline28 _NativeCupertinoHttp_wrapBlockingBlock_9qxjkl(
    _BlockingTrampoline28 block, _BlockingTrampoline28 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionDownloadDelegate() { return @protocol(NSURLSessionDownloadDelegate); }

typedef void  (^_ListenerTrampoline29)(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline29 _NativeCupertinoHttp_wrapListenerBlock_3lo3bb(_ListenerTrampoline29 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retain(arg4));
  };
}

typedef void  (^_BlockingTrampoline29)(void * waiter, void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline29 _NativeCupertinoHttp_wrapBlockingBlock_3lo3bb(
    _BlockingTrampoline29 block, _BlockingTrampoline29 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retain(arg4));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retain(arg4));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionWebSocketDelegate() { return @protocol(NSURLSessionWebSocketDelegate); }

typedef void  (^_ListenerTrampoline30)(id arg0, unsigned long arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline30 _NativeCupertinoHttp_wrapListenerBlock_16ko9u(_ListenerTrampoline30 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, unsigned long arg1, BOOL * arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1, arg2);
  };
}

typedef void  (^_BlockingTrampoline30)(void * waiter, id arg0, unsigned long arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline30 _NativeCupertinoHttp_wrapBlockingBlock_16ko9u(
    _BlockingTrampoline30 block, _BlockingTrampoline30 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, unsigned long arg1, BOOL * arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), arg1, arg2);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), arg1, arg2);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline31)(id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline31 _NativeCupertinoHttp_wrapListenerBlock_1j2nt86(_ListenerTrampoline31 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retainBlock(arg0), objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^_BlockingTrampoline31)(void * waiter, id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline31 _NativeCupertinoHttp_wrapBlockingBlock_1j2nt86(
    _BlockingTrampoline31 block, _BlockingTrampoline31 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, id arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retainBlock(arg0), objc_retain(arg1), objc_retain(arg2));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retainBlock(arg0), objc_retain(arg1), objc_retain(arg2));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline32)(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline32 _NativeCupertinoHttp_wrapListenerBlock_8wbg7l(_ListenerTrampoline32 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1, arg2, arg3);
  };
}

typedef void  (^_BlockingTrampoline32)(void * waiter, id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline32 _NativeCupertinoHttp_wrapBlockingBlock_8wbg7l(
    _BlockingTrampoline32 block, _BlockingTrampoline32 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), arg1, arg2, arg3);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), arg1, arg2, arg3);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline33)(id arg0, BOOL * arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline33 _NativeCupertinoHttp_wrapListenerBlock_148br51(_ListenerTrampoline33 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, BOOL * arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1);
  };
}

typedef void  (^_BlockingTrampoline33)(void * waiter, id arg0, BOOL * arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline33 _NativeCupertinoHttp_wrapBlockingBlock_148br51(
    _BlockingTrampoline33 block, _BlockingTrampoline33 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, BOOL * arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), arg1);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline34)(unsigned short * arg0, unsigned long arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline34 _NativeCupertinoHttp_wrapListenerBlock_vhbh5h(_ListenerTrampoline34 block) NS_RETURNS_RETAINED {
  return ^void(unsigned short * arg0, unsigned long arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline34)(void * waiter, unsigned short * arg0, unsigned long arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline34 _NativeCupertinoHttp_wrapBlockingBlock_vhbh5h(
    _BlockingTrampoline34 block, _BlockingTrampoline34 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(unsigned short * arg0, unsigned long arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, arg1);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline35)(void * arg0, unsigned long arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline35 _NativeCupertinoHttp_wrapListenerBlock_zuf90e(_ListenerTrampoline35 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, unsigned long arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline35)(void * waiter, void * arg0, unsigned long arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline35 _NativeCupertinoHttp_wrapBlockingBlock_zuf90e(
    _BlockingTrampoline35 block, _BlockingTrampoline35 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, unsigned long arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, arg1);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline36)(void * arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline36 _NativeCupertinoHttp_wrapListenerBlock_ovsamd(_ListenerTrampoline36 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline36)(void * waiter, void * arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline36 _NativeCupertinoHttp_wrapBlockingBlock_ovsamd(
    _BlockingTrampoline36 block, _BlockingTrampoline36 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0);
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}

typedef void  (^_ListenerTrampoline37)(id arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline37 _NativeCupertinoHttp_wrapListenerBlock_4ya7yd(_ListenerTrampoline37 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

typedef void  (^_BlockingTrampoline37)(void * waiter, id arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline37 _NativeCupertinoHttp_wrapBlockingBlock_4ya7yd(
    _BlockingTrampoline37 block, _BlockingTrampoline37 listenerBlock, double timeoutSeconds,
    void* (*newWaiter)(), void (*awaitWaiter)(void*, double))
        NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, id arg2, id arg3) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retain(arg0), objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retain(arg0), objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
      awaitWaiter(waiter, timeoutSeconds);
    }
  };
}
