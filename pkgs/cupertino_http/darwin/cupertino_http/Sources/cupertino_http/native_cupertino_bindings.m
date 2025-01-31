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

#if !__has_feature(objc_arc)
#error "This file must be compiled with ARC enabled"
#endif

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

typedef void  (^_ListenerTrampoline1)(id arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline1 _NativeCupertinoHttp_wrapListenerBlock_xtuoz7(_ListenerTrampoline1 block) NS_RETURNS_RETAINED {
  return ^void(id arg0) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0));
  };
}

typedef void  (^_BlockingTrampoline1)(void * waiter, id arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline1 _NativeCupertinoHttp_wrapBlockingBlock_xtuoz7(
    _BlockingTrampoline1 block, _BlockingTrampoline1 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, (__bridge id)(__bridge_retained void*)(arg0));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline2)(void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline2 _NativeCupertinoHttp_wrapListenerBlock_18v1jvf(_ListenerTrampoline2 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1));
  };
}

typedef void  (^_BlockingTrampoline2)(void * waiter, void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline2 _NativeCupertinoHttp_wrapBlockingBlock_18v1jvf(
    _BlockingTrampoline2 block, _BlockingTrampoline2 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline3)(id arg0, id arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline3 _NativeCupertinoHttp_wrapListenerBlock_1o83rbn(_ListenerTrampoline3 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, BOOL * arg2) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1), arg2);
  };
}

typedef void  (^_BlockingTrampoline3)(void * waiter, id arg0, id arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline3 _NativeCupertinoHttp_wrapBlockingBlock_1o83rbn(
    _BlockingTrampoline3 block, _BlockingTrampoline3 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, BOOL * arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1), arg2);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1), arg2);
      awaitWaiter(waiter);
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
    _BlockingTrampoline4 block, _BlockingTrampoline4 listenerBlock,
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
    _BlockingTrampoline5 block, _BlockingTrampoline5 listenerBlock,
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
    _BlockingTrampoline6 block, _BlockingTrampoline6 listenerBlock,
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

typedef void  (^_ListenerTrampoline7)(id arg0, int arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline7 _NativeCupertinoHttp_wrapListenerBlock_18kzm6a(_ListenerTrampoline7 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, int arg1) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), arg1);
  };
}

typedef void  (^_BlockingTrampoline7)(void * waiter, id arg0, int arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline7 _NativeCupertinoHttp_wrapBlockingBlock_18kzm6a(
    _BlockingTrampoline7 block, _BlockingTrampoline7 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, int arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, (__bridge id)(__bridge_retained void*)(arg0), arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), arg1);
      awaitWaiter(waiter);
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
    _BlockingTrampoline8 block, _BlockingTrampoline8 listenerBlock,
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

typedef void  (^_ListenerTrampoline9)(BOOL arg0, id arg1, int arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline9 _NativeCupertinoHttp_wrapListenerBlock_og5b6y(_ListenerTrampoline9 block) NS_RETURNS_RETAINED {
  return ^void(BOOL arg0, id arg1, int arg2) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), arg2);
  };
}

typedef void  (^_BlockingTrampoline9)(void * waiter, BOOL arg0, id arg1, int arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline9 _NativeCupertinoHttp_wrapBlockingBlock_og5b6y(
    _BlockingTrampoline9 block, _BlockingTrampoline9 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(BOOL arg0, id arg1, int arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), arg2);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), arg2);
      awaitWaiter(waiter);
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
    _BlockingTrampoline10 block, _BlockingTrampoline10 listenerBlock,
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
    _BlockingTrampoline11 block, _BlockingTrampoline11 listenerBlock,
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
    _BlockingTrampoline12 block, _BlockingTrampoline12 listenerBlock,
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

typedef void  (^_ListenerTrampoline13)(id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline13 _NativeCupertinoHttp_wrapListenerBlock_pfv6jd(_ListenerTrampoline13 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1));
  };
}

typedef void  (^_BlockingTrampoline13)(void * waiter, id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline13 _NativeCupertinoHttp_wrapBlockingBlock_pfv6jd(
    _BlockingTrampoline13 block, _BlockingTrampoline13 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline14)(id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline14 _NativeCupertinoHttp_wrapListenerBlock_18qun1e(_ListenerTrampoline14 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1), objc_retainBlock(arg2));
  };
}

typedef void  (^_BlockingTrampoline14)(void * waiter, id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline14 _NativeCupertinoHttp_wrapBlockingBlock_18qun1e(
    _BlockingTrampoline14 block, _BlockingTrampoline14 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, id arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1), objc_retainBlock(arg2));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1), objc_retainBlock(arg2));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline15)(id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline15 _NativeCupertinoHttp_wrapListenerBlock_o762yo(_ListenerTrampoline15 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), objc_retainBlock(arg1));
  };
}

typedef void  (^_BlockingTrampoline15)(void * waiter, id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline15 _NativeCupertinoHttp_wrapBlockingBlock_o762yo(
    _BlockingTrampoline15 block, _BlockingTrampoline15 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, (__bridge id)(__bridge_retained void*)(arg0), objc_retainBlock(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), objc_retainBlock(arg1));
      awaitWaiter(waiter);
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
    _BlockingTrampoline16 block, _BlockingTrampoline16 listenerBlock,
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

typedef void  (^_ListenerTrampoline17)(id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline17 _NativeCupertinoHttp_wrapListenerBlock_r8gdi7(_ListenerTrampoline17 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  };
}

typedef void  (^_BlockingTrampoline17)(void * waiter, id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline17 _NativeCupertinoHttp_wrapBlockingBlock_r8gdi7(
    _BlockingTrampoline17 block, _BlockingTrampoline17 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, id arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
      awaitWaiter(waiter);
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
    _BlockingTrampoline18 block, _BlockingTrampoline18 listenerBlock,
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

typedef void  (^_ListenerTrampoline19)(void * arg0, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline19 _NativeCupertinoHttp_wrapListenerBlock_xx612k(_ListenerTrampoline19 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), objc_retainBlock(arg4));
  };
}

typedef void  (^_BlockingTrampoline19)(void * waiter, void * arg0, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline19 _NativeCupertinoHttp_wrapBlockingBlock_xx612k(
    _BlockingTrampoline19 block, _BlockingTrampoline19 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), objc_retainBlock(arg4));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), objc_retainBlock(arg4));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline20)(void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline20 _NativeCupertinoHttp_wrapListenerBlock_1tz5yf(_ListenerTrampoline20 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3));
  };
}

typedef void  (^_BlockingTrampoline20)(void * waiter, void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline20 _NativeCupertinoHttp_wrapBlockingBlock_1tz5yf(
    _BlockingTrampoline20 block, _BlockingTrampoline20 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline21)(void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline21 _NativeCupertinoHttp_wrapListenerBlock_fjrv01(_ListenerTrampoline21 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  };
}

typedef void  (^_BlockingTrampoline21)(void * waiter, void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline21 _NativeCupertinoHttp_wrapBlockingBlock_fjrv01(
    _BlockingTrampoline21 block, _BlockingTrampoline21 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline22)(NSURLSessionDelayedRequestDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline22 _NativeCupertinoHttp_wrapListenerBlock_1otpo83(_ListenerTrampoline22 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionDelayedRequestDisposition arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1));
  };
}

typedef void  (^_BlockingTrampoline22)(void * waiter, NSURLSessionDelayedRequestDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline22 _NativeCupertinoHttp_wrapBlockingBlock_1otpo83(
    _BlockingTrampoline22 block, _BlockingTrampoline22 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(NSURLSessionDelayedRequestDisposition arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline23)(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline23 _NativeCupertinoHttp_wrapListenerBlock_l2g8ke(_ListenerTrampoline23 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), (__bridge id)(__bridge_retained void*)(arg4), objc_retainBlock(arg5));
  };
}

typedef void  (^_BlockingTrampoline23)(void * waiter, void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline23 _NativeCupertinoHttp_wrapBlockingBlock_l2g8ke(
    _BlockingTrampoline23 block, _BlockingTrampoline23 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), (__bridge id)(__bridge_retained void*)(arg4), objc_retainBlock(arg5));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), (__bridge id)(__bridge_retained void*)(arg4), objc_retainBlock(arg5));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline24)(NSURLSessionAuthChallengeDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline24 _NativeCupertinoHttp_wrapListenerBlock_n8yd09(_ListenerTrampoline24 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionAuthChallengeDisposition arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1));
  };
}

typedef void  (^_BlockingTrampoline24)(void * waiter, NSURLSessionAuthChallengeDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline24 _NativeCupertinoHttp_wrapBlockingBlock_n8yd09(
    _BlockingTrampoline24 block, _BlockingTrampoline24 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(NSURLSessionAuthChallengeDisposition arg0, id arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline25)(void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline25 _NativeCupertinoHttp_wrapListenerBlock_bklti2(_ListenerTrampoline25 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), objc_retainBlock(arg3));
  };
}

typedef void  (^_BlockingTrampoline25)(void * waiter, void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline25 _NativeCupertinoHttp_wrapBlockingBlock_bklti2(
    _BlockingTrampoline25 block, _BlockingTrampoline25 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), objc_retainBlock(arg3));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), objc_retainBlock(arg3));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline26)(void * arg0, id arg1, id arg2, int64_t arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline26 _NativeCupertinoHttp_wrapListenerBlock_jyim80(_ListenerTrampoline26 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, objc_retainBlock(arg4));
  };
}

typedef void  (^_BlockingTrampoline26)(void * waiter, void * arg0, id arg1, id arg2, int64_t arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline26 _NativeCupertinoHttp_wrapBlockingBlock_jyim80(
    _BlockingTrampoline26 block, _BlockingTrampoline26 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, id arg4) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, objc_retainBlock(arg4));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, objc_retainBlock(arg4));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline27)(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline27 _NativeCupertinoHttp_wrapListenerBlock_h68abb(_ListenerTrampoline27 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, arg4, arg5);
  };
}

typedef void  (^_BlockingTrampoline27)(void * waiter, void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline27 _NativeCupertinoHttp_wrapBlockingBlock_h68abb(
    _BlockingTrampoline27 block, _BlockingTrampoline27 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, arg4, arg5);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, arg4, arg5);
      awaitWaiter(waiter);
    }
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionDataDelegate(void) { return @protocol(NSURLSessionDataDelegate); }

typedef void  (^_ListenerTrampoline28)(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline28 _NativeCupertinoHttp_wrapListenerBlock_ly2579(_ListenerTrampoline28 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, arg4);
  };
}

typedef void  (^_BlockingTrampoline28)(void * waiter, void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline28 _NativeCupertinoHttp_wrapBlockingBlock_ly2579(
    _BlockingTrampoline28 block, _BlockingTrampoline28 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, arg4);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, arg4);
      awaitWaiter(waiter);
    }
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionDownloadDelegate(void) { return @protocol(NSURLSessionDownloadDelegate); }

typedef void  (^_ListenerTrampoline29)(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline29 _NativeCupertinoHttp_wrapListenerBlock_1lx650f(_ListenerTrampoline29 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, (__bridge id)(__bridge_retained void*)(arg4));
  };
}

typedef void  (^_BlockingTrampoline29)(void * waiter, void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline29 _NativeCupertinoHttp_wrapBlockingBlock_1lx650f(
    _BlockingTrampoline29 block, _BlockingTrampoline29 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, (__bridge id)(__bridge_retained void*)(arg4));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, (__bridge id)(__bridge_retained void*)(arg4));
      awaitWaiter(waiter);
    }
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionWebSocketDelegate(void) { return @protocol(NSURLSessionWebSocketDelegate); }

typedef void  (^_ListenerTrampoline30)(id arg0, unsigned long arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline30 _NativeCupertinoHttp_wrapListenerBlock_1p9ui4q(_ListenerTrampoline30 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, unsigned long arg1, BOOL * arg2) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
  };
}

typedef void  (^_BlockingTrampoline30)(void * waiter, id arg0, unsigned long arg1, BOOL * arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline30 _NativeCupertinoHttp_wrapBlockingBlock_1p9ui4q(
    _BlockingTrampoline30 block, _BlockingTrampoline30 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, unsigned long arg1, BOOL * arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline31)(id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline31 _NativeCupertinoHttp_wrapListenerBlock_1b3bb6a(_ListenerTrampoline31 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retainBlock(arg0), (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  };
}

typedef void  (^_BlockingTrampoline31)(void * waiter, id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline31 _NativeCupertinoHttp_wrapBlockingBlock_1b3bb6a(
    _BlockingTrampoline31 block, _BlockingTrampoline31 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, id arg1, id arg2) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, objc_retainBlock(arg0), (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, objc_retainBlock(arg0), (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline32)(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline32 _NativeCupertinoHttp_wrapListenerBlock_lmc3p5(_ListenerTrampoline32 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), arg1, arg2, arg3);
  };
}

typedef void  (^_BlockingTrampoline32)(void * waiter, id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline32 _NativeCupertinoHttp_wrapBlockingBlock_lmc3p5(
    _BlockingTrampoline32 block, _BlockingTrampoline32 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2, arg3);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), arg1, arg2, arg3);
      awaitWaiter(waiter);
    }
  };
}

typedef void  (^_ListenerTrampoline33)(id arg0, BOOL * arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline33 _NativeCupertinoHttp_wrapListenerBlock_t8l8el(_ListenerTrampoline33 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, BOOL * arg1) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), arg1);
  };
}

typedef void  (^_BlockingTrampoline33)(void * waiter, id arg0, BOOL * arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline33 _NativeCupertinoHttp_wrapBlockingBlock_t8l8el(
    _BlockingTrampoline33 block, _BlockingTrampoline33 listenerBlock,
    void* (*newWaiter)(), void (*awaitWaiter)(void*)) NS_RETURNS_RETAINED {
  NSThread *targetThread = [NSThread currentThread];
  return ^void(id arg0, BOOL * arg1) {
    if ([NSThread currentThread] == targetThread) {
      objc_retainBlock(block);
      block(nil, (__bridge id)(__bridge_retained void*)(arg0), arg1);
    } else {
      void* waiter = newWaiter();
      objc_retainBlock(listenerBlock);
      listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), arg1);
      awaitWaiter(waiter);
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
    _BlockingTrampoline34 block, _BlockingTrampoline34 listenerBlock,
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
    _BlockingTrampoline35 block, _BlockingTrampoline35 listenerBlock,
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
    _BlockingTrampoline36 block, _BlockingTrampoline36 listenerBlock,
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
