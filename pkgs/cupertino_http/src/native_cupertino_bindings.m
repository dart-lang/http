#include <stdint.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

typedef struct {
  int64_t version;
  void* (*newWaiter)(void);
  void (*awaitWaiter)(void*);
  void* (*currentIsolate)(void);
  void (*enterIsolate)(void*);
  void (*exitIsolate)(void);
  int64_t (*getMainPortId)(void);
  bool (*getCurrentThreadOwnsIsolate)(int64_t);
  void (*invokeListenerPortBlock)(int64_t port, void*);
  void (*invokeBlockingPortBlock)(int64_t port, void*, void*);
} DOBJC_Context;

id objc_retainBlock(id);

#define BLOCKING_BLOCK_IMPL(ctx, TYPE, SIG, INVOKE_DIRECT, INVOKE_LISTENER)    \
  assert(ctx->version >= 1);                                                   \
  void* targetIsolate = ctx->currentIsolate();                                 \
  int64_t targetPort = ctx->getMainPortId == NULL ? 0 : ctx->getMainPortId();  \
  __block __weak TYPE weakSelfBlock = nil;                                     \
  TYPE strongSelfBlock = [SIG {                                                \
    void* currentIsolate = ctx->currentIsolate();                              \
    bool mayEnterIsolate =                                                     \
        currentIsolate == NULL &&                                              \
        ctx->getCurrentThreadOwnsIsolate != NULL &&                            \
        ctx->getCurrentThreadOwnsIsolate(targetPort);                          \
    if (currentIsolate == targetIsolate || mayEnterIsolate) {                  \
      if (mayEnterIsolate) {                                                   \
        ctx->enterIsolate(targetIsolate);                                      \
      }                                                                        \
      INVOKE_DIRECT;                                                           \
      if (mayEnterIsolate) {                                                   \
        ctx->exitIsolate();                                                    \
      }                                                                        \
    } else {                                                                   \
      void* waiter = ctx->newWaiter();                                         \
      TYPE selfRetain = [weakSelfBlock copy];                                  \
      INVOKE_LISTENER;                                                         \
      ctx->awaitWaiter(waiter);                                                \
      (void)selfRetain;                                                        \
    }                                                                          \
  } copy];                                                                     \
  weakSelfBlock = strongSelfBlock;                                             \
  return strongSelfBlock;


__attribute__((visibility("default"))) __attribute__((used))
Protocol* _1tf3our_NSURLSessionDataDelegate(void) { return @protocol(NSURLSessionDataDelegate); }

__attribute__((visibility("default"))) __attribute__((used))
Protocol* _1tf3our_NSURLSessionDownloadDelegate(void) { return @protocol(NSURLSessionDownloadDelegate); }

__attribute__((visibility("default"))) __attribute__((used))
Protocol* _1tf3our_NSURLSessionWebSocketDelegate(void) { return @protocol(NSURLSessionWebSocketDelegate); }

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_1pl9qdv : NSObject
@property (copy) id block;

@end
@implementation _1tf3our_BlockArgs_1pl9qdv
@end

typedef void  (^_ListenerTrampoline)(void);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline _1tf3our_wrapListenerBlock_1pl9qdv(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline weakSelfBlock = nil;
  _ListenerTrampoline strongSelfBlock = [^void() {
    @autoreleasepool {
      _1tf3our_BlockArgs_1pl9qdv* args = [[_1tf3our_BlockArgs_1pl9qdv alloc] init];
      args.block = weakSelfBlock;
      
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline)(void * waiter);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline _1tf3our_wrapBlockingBlock_1pl9qdv(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline, ^void(), {
    @autoreleasepool {
      _1tf3our_BlockArgs_1pl9qdv* args = [[_1tf3our_BlockArgs_1pl9qdv alloc] init];
      args.block = weakSelfBlock;
      
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_1pl9qdv* args = [[_1tf3our_BlockArgs_1pl9qdv alloc] init];
      args.block = weakSelfBlock;
      
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_xtuoz7 : NSObject
@property (copy) id block;
@property (strong) id arg0;
@end
@implementation _1tf3our_BlockArgs_xtuoz7
@end

typedef void  (^_ListenerTrampoline_1)(id arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_1 _1tf3our_wrapListenerBlock_xtuoz7(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_1 weakSelfBlock = nil;
  _ListenerTrampoline_1 strongSelfBlock = [^void(id arg0) {
    @autoreleasepool {
      _1tf3our_BlockArgs_xtuoz7* args = [[_1tf3our_BlockArgs_xtuoz7 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_1)(void * waiter, id arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_1 _1tf3our_wrapBlockingBlock_xtuoz7(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_1, ^void(id arg0), {
    @autoreleasepool {
      _1tf3our_BlockArgs_xtuoz7* args = [[_1tf3our_BlockArgs_xtuoz7 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_xtuoz7* args = [[_1tf3our_BlockArgs_xtuoz7 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_r8gdi7 : NSObject
@property (copy) id block;
@property (strong) id arg0;
@property (strong) id arg1;
@property (strong) id arg2;
@end
@implementation _1tf3our_BlockArgs_r8gdi7
@end

typedef void  (^_ListenerTrampoline_2)(id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_2 _1tf3our_wrapListenerBlock_r8gdi7(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_2 weakSelfBlock = nil;
  _ListenerTrampoline_2 strongSelfBlock = [^void(id arg0, id arg1, id arg2) {
    @autoreleasepool {
      _1tf3our_BlockArgs_r8gdi7* args = [[_1tf3our_BlockArgs_r8gdi7 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_2)(void * waiter, id arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_2 _1tf3our_wrapBlockingBlock_r8gdi7(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_2, ^void(id arg0, id arg1, id arg2), {
    @autoreleasepool {
      _1tf3our_BlockArgs_r8gdi7* args = [[_1tf3our_BlockArgs_r8gdi7 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_r8gdi7* args = [[_1tf3our_BlockArgs_r8gdi7 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_n8yd09 : NSObject
@property (copy) id block;
@property NSURLSessionAuthChallengeDisposition arg0;
@property (strong) id arg1;
@end
@implementation _1tf3our_BlockArgs_n8yd09
@end

typedef void  (^_ListenerTrampoline_3)(NSURLSessionAuthChallengeDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_3 _1tf3our_wrapListenerBlock_n8yd09(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_3 weakSelfBlock = nil;
  _ListenerTrampoline_3 strongSelfBlock = [^void(NSURLSessionAuthChallengeDisposition arg0, id arg1) {
    @autoreleasepool {
      _1tf3our_BlockArgs_n8yd09* args = [[_1tf3our_BlockArgs_n8yd09 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_3)(void * waiter, NSURLSessionAuthChallengeDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_3 _1tf3our_wrapBlockingBlock_n8yd09(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_3, ^void(NSURLSessionAuthChallengeDisposition arg0, id arg1), {
    @autoreleasepool {
      _1tf3our_BlockArgs_n8yd09* args = [[_1tf3our_BlockArgs_n8yd09 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_n8yd09* args = [[_1tf3our_BlockArgs_n8yd09 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_1otpo83 : NSObject
@property (copy) id block;
@property NSURLSessionDelayedRequestDisposition arg0;
@property (strong) id arg1;
@end
@implementation _1tf3our_BlockArgs_1otpo83
@end

typedef void  (^_ListenerTrampoline_4)(NSURLSessionDelayedRequestDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_4 _1tf3our_wrapListenerBlock_1otpo83(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_4 weakSelfBlock = nil;
  _ListenerTrampoline_4 strongSelfBlock = [^void(NSURLSessionDelayedRequestDisposition arg0, id arg1) {
    @autoreleasepool {
      _1tf3our_BlockArgs_1otpo83* args = [[_1tf3our_BlockArgs_1otpo83 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_4)(void * waiter, NSURLSessionDelayedRequestDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_4 _1tf3our_wrapBlockingBlock_1otpo83(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_4, ^void(NSURLSessionDelayedRequestDisposition arg0, id arg1), {
    @autoreleasepool {
      _1tf3our_BlockArgs_1otpo83* args = [[_1tf3our_BlockArgs_1otpo83 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_1otpo83* args = [[_1tf3our_BlockArgs_1otpo83 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_16sve1d : NSObject
@property (copy) id block;
@property NSURLSessionResponseDisposition arg0;
@end
@implementation _1tf3our_BlockArgs_16sve1d
@end

typedef void  (^_ListenerTrampoline_5)(NSURLSessionResponseDisposition arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_5 _1tf3our_wrapListenerBlock_16sve1d(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_5 weakSelfBlock = nil;
  _ListenerTrampoline_5 strongSelfBlock = [^void(NSURLSessionResponseDisposition arg0) {
    @autoreleasepool {
      _1tf3our_BlockArgs_16sve1d* args = [[_1tf3our_BlockArgs_16sve1d alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_5)(void * waiter, NSURLSessionResponseDisposition arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_5 _1tf3our_wrapBlockingBlock_16sve1d(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_5, ^void(NSURLSessionResponseDisposition arg0), {
    @autoreleasepool {
      _1tf3our_BlockArgs_16sve1d* args = [[_1tf3our_BlockArgs_16sve1d alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_16sve1d* args = [[_1tf3our_BlockArgs_16sve1d alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_pfv6jd : NSObject
@property (copy) id block;
@property (strong) id arg0;
@property (strong) id arg1;
@end
@implementation _1tf3our_BlockArgs_pfv6jd
@end

typedef void  (^_ListenerTrampoline_6)(id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_6 _1tf3our_wrapListenerBlock_pfv6jd(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_6 weakSelfBlock = nil;
  _ListenerTrampoline_6 strongSelfBlock = [^void(id arg0, id arg1) {
    @autoreleasepool {
      _1tf3our_BlockArgs_pfv6jd* args = [[_1tf3our_BlockArgs_pfv6jd alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_6)(void * waiter, id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_6 _1tf3our_wrapBlockingBlock_pfv6jd(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_6, ^void(id arg0, id arg1), {
    @autoreleasepool {
      _1tf3our_BlockArgs_pfv6jd* args = [[_1tf3our_BlockArgs_pfv6jd alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_pfv6jd* args = [[_1tf3our_BlockArgs_pfv6jd alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_18v1jvf : NSObject
@property (copy) id block;
@property void * arg0;
@property (strong) id arg1;
@end
@implementation _1tf3our_BlockArgs_18v1jvf
@end

typedef void  (^_ListenerTrampoline_7)(void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_7 _1tf3our_wrapListenerBlock_18v1jvf(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_7 weakSelfBlock = nil;
  _ListenerTrampoline_7 strongSelfBlock = [^void(void * arg0, id arg1) {
    @autoreleasepool {
      _1tf3our_BlockArgs_18v1jvf* args = [[_1tf3our_BlockArgs_18v1jvf alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_7)(void * waiter, void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_7 _1tf3our_wrapBlockingBlock_18v1jvf(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_7, ^void(void * arg0, id arg1), {
    @autoreleasepool {
      _1tf3our_BlockArgs_18v1jvf* args = [[_1tf3our_BlockArgs_18v1jvf alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_18v1jvf* args = [[_1tf3our_BlockArgs_18v1jvf alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

typedef void  (^_ProtocolTrampoline)(void * sel, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _1tf3our_protocolTrampoline_18v1jvf(id target, void * sel, id arg1) {
  return ((_ProtocolTrampoline)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_fjrv01 : NSObject
@property (copy) id block;
@property void * arg0;
@property (strong) id arg1;
@property (strong) id arg2;
@end
@implementation _1tf3our_BlockArgs_fjrv01
@end

typedef void  (^_ListenerTrampoline_8)(void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_8 _1tf3our_wrapListenerBlock_fjrv01(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_8 weakSelfBlock = nil;
  _ListenerTrampoline_8 strongSelfBlock = [^void(void * arg0, id arg1, id arg2) {
    @autoreleasepool {
      _1tf3our_BlockArgs_fjrv01* args = [[_1tf3our_BlockArgs_fjrv01 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_8)(void * waiter, void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_8 _1tf3our_wrapBlockingBlock_fjrv01(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_8, ^void(void * arg0, id arg1, id arg2), {
    @autoreleasepool {
      _1tf3our_BlockArgs_fjrv01* args = [[_1tf3our_BlockArgs_fjrv01 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_fjrv01* args = [[_1tf3our_BlockArgs_fjrv01 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

typedef void  (^_ProtocolTrampoline_1)(void * sel, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
void  _1tf3our_protocolTrampoline_fjrv01(id target, void * sel, id arg1, id arg2) {
  return ((_ProtocolTrampoline_1)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2);
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_bklti2 : NSObject
@property (copy) id block;
@property void * arg0;
@property (strong) id arg1;
@property (strong) id arg2;
@property (copy) id arg3;
@end
@implementation _1tf3our_BlockArgs_bklti2
@end

typedef void  (^_ListenerTrampoline_9)(void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_9 _1tf3our_wrapListenerBlock_bklti2(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_9 weakSelfBlock = nil;
  _ListenerTrampoline_9 strongSelfBlock = [^void(void * arg0, id arg1, id arg2, id arg3) {
    @autoreleasepool {
      _1tf3our_BlockArgs_bklti2* args = [[_1tf3our_BlockArgs_bklti2 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_9)(void * waiter, void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_9 _1tf3our_wrapBlockingBlock_bklti2(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_9, ^void(void * arg0, id arg1, id arg2, id arg3), {
    @autoreleasepool {
      _1tf3our_BlockArgs_bklti2* args = [[_1tf3our_BlockArgs_bklti2 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_bklti2* args = [[_1tf3our_BlockArgs_bklti2 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

typedef void  (^_ProtocolTrampoline_2)(void * sel, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
void  _1tf3our_protocolTrampoline_bklti2(id target, void * sel, id arg1, id arg2, id arg3) {
  return ((_ProtocolTrampoline_2)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3);
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_xx612k : NSObject
@property (copy) id block;
@property void * arg0;
@property (strong) id arg1;
@property (strong) id arg2;
@property (strong) id arg3;
@property (copy) id arg4;
@end
@implementation _1tf3our_BlockArgs_xx612k
@end

typedef void  (^_ListenerTrampoline_10)(void * arg0, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_10 _1tf3our_wrapListenerBlock_xx612k(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_10 weakSelfBlock = nil;
  _ListenerTrampoline_10 strongSelfBlock = [^void(void * arg0, id arg1, id arg2, id arg3, id arg4) {
    @autoreleasepool {
      _1tf3our_BlockArgs_xx612k* args = [[_1tf3our_BlockArgs_xx612k alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_10)(void * waiter, void * arg0, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_10 _1tf3our_wrapBlockingBlock_xx612k(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_10, ^void(void * arg0, id arg1, id arg2, id arg3, id arg4), {
    @autoreleasepool {
      _1tf3our_BlockArgs_xx612k* args = [[_1tf3our_BlockArgs_xx612k alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_xx612k* args = [[_1tf3our_BlockArgs_xx612k alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

typedef void  (^_ProtocolTrampoline_3)(void * sel, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
void  _1tf3our_protocolTrampoline_xx612k(id target, void * sel, id arg1, id arg2, id arg3, id arg4) {
  return ((_ProtocolTrampoline_3)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4);
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_1tz5yf : NSObject
@property (copy) id block;
@property void * arg0;
@property (strong) id arg1;
@property (strong) id arg2;
@property (strong) id arg3;
@end
@implementation _1tf3our_BlockArgs_1tz5yf
@end

typedef void  (^_ListenerTrampoline_11)(void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_11 _1tf3our_wrapListenerBlock_1tz5yf(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_11 weakSelfBlock = nil;
  _ListenerTrampoline_11 strongSelfBlock = [^void(void * arg0, id arg1, id arg2, id arg3) {
    @autoreleasepool {
      _1tf3our_BlockArgs_1tz5yf* args = [[_1tf3our_BlockArgs_1tz5yf alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_11)(void * waiter, void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_11 _1tf3our_wrapBlockingBlock_1tz5yf(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_11, ^void(void * arg0, id arg1, id arg2, id arg3), {
    @autoreleasepool {
      _1tf3our_BlockArgs_1tz5yf* args = [[_1tf3our_BlockArgs_1tz5yf alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_1tz5yf* args = [[_1tf3our_BlockArgs_1tz5yf alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

typedef void  (^_ProtocolTrampoline_4)(void * sel, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
void  _1tf3our_protocolTrampoline_1tz5yf(id target, void * sel, id arg1, id arg2, id arg3) {
  return ((_ProtocolTrampoline_4)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3);
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_ly2579 : NSObject
@property (copy) id block;
@property void * arg0;
@property (strong) id arg1;
@property (strong) id arg2;
@property int64_t arg3;
@property int64_t arg4;
@end
@implementation _1tf3our_BlockArgs_ly2579
@end

typedef void  (^_ListenerTrampoline_12)(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_12 _1tf3our_wrapListenerBlock_ly2579(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_12 weakSelfBlock = nil;
  _ListenerTrampoline_12 strongSelfBlock = [^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4) {
    @autoreleasepool {
      _1tf3our_BlockArgs_ly2579* args = [[_1tf3our_BlockArgs_ly2579 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_12)(void * waiter, void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_12 _1tf3our_wrapBlockingBlock_ly2579(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_12, ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4), {
    @autoreleasepool {
      _1tf3our_BlockArgs_ly2579* args = [[_1tf3our_BlockArgs_ly2579 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_ly2579* args = [[_1tf3our_BlockArgs_ly2579 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

typedef void  (^_ProtocolTrampoline_5)(void * sel, id arg1, id arg2, int64_t arg3, int64_t arg4);
__attribute__((visibility("default"))) __attribute__((used))
void  _1tf3our_protocolTrampoline_ly2579(id target, void * sel, id arg1, id arg2, int64_t arg3, int64_t arg4) {
  return ((_ProtocolTrampoline_5)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4);
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_h68abb : NSObject
@property (copy) id block;
@property void * arg0;
@property (strong) id arg1;
@property (strong) id arg2;
@property int64_t arg3;
@property int64_t arg4;
@property int64_t arg5;
@end
@implementation _1tf3our_BlockArgs_h68abb
@end

typedef void  (^_ListenerTrampoline_13)(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_13 _1tf3our_wrapListenerBlock_h68abb(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_13 weakSelfBlock = nil;
  _ListenerTrampoline_13 strongSelfBlock = [^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    @autoreleasepool {
      _1tf3our_BlockArgs_h68abb* args = [[_1tf3our_BlockArgs_h68abb alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      args.arg5 = arg5;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_13)(void * waiter, void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_13 _1tf3our_wrapBlockingBlock_h68abb(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_13, ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5), {
    @autoreleasepool {
      _1tf3our_BlockArgs_h68abb* args = [[_1tf3our_BlockArgs_h68abb alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      args.arg5 = arg5;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_h68abb* args = [[_1tf3our_BlockArgs_h68abb alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      args.arg5 = arg5;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

typedef void  (^_ProtocolTrampoline_6)(void * sel, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5);
__attribute__((visibility("default"))) __attribute__((used))
void  _1tf3our_protocolTrampoline_h68abb(id target, void * sel, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
  return ((_ProtocolTrampoline_6)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4, arg5);
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_jyim80 : NSObject
@property (copy) id block;
@property void * arg0;
@property (strong) id arg1;
@property (strong) id arg2;
@property int64_t arg3;
@property (copy) id arg4;
@end
@implementation _1tf3our_BlockArgs_jyim80
@end

typedef void  (^_ListenerTrampoline_14)(void * arg0, id arg1, id arg2, int64_t arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_14 _1tf3our_wrapListenerBlock_jyim80(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_14 weakSelfBlock = nil;
  _ListenerTrampoline_14 strongSelfBlock = [^void(void * arg0, id arg1, id arg2, int64_t arg3, id arg4) {
    @autoreleasepool {
      _1tf3our_BlockArgs_jyim80* args = [[_1tf3our_BlockArgs_jyim80 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_14)(void * waiter, void * arg0, id arg1, id arg2, int64_t arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_14 _1tf3our_wrapBlockingBlock_jyim80(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_14, ^void(void * arg0, id arg1, id arg2, int64_t arg3, id arg4), {
    @autoreleasepool {
      _1tf3our_BlockArgs_jyim80* args = [[_1tf3our_BlockArgs_jyim80 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_jyim80* args = [[_1tf3our_BlockArgs_jyim80 alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

typedef void  (^_ProtocolTrampoline_7)(void * sel, id arg1, id arg2, int64_t arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
void  _1tf3our_protocolTrampoline_jyim80(id target, void * sel, id arg1, id arg2, int64_t arg3, id arg4) {
  return ((_ProtocolTrampoline_7)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4);
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_l2g8ke : NSObject
@property (copy) id block;
@property void * arg0;
@property (strong) id arg1;
@property (strong) id arg2;
@property (strong) id arg3;
@property (strong) id arg4;
@property (copy) id arg5;
@end
@implementation _1tf3our_BlockArgs_l2g8ke
@end

typedef void  (^_ListenerTrampoline_15)(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_15 _1tf3our_wrapListenerBlock_l2g8ke(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_15 weakSelfBlock = nil;
  _ListenerTrampoline_15 strongSelfBlock = [^void(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5) {
    @autoreleasepool {
      _1tf3our_BlockArgs_l2g8ke* args = [[_1tf3our_BlockArgs_l2g8ke alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      args.arg5 = arg5;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_15)(void * waiter, void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_15 _1tf3our_wrapBlockingBlock_l2g8ke(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_15, ^void(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5), {
    @autoreleasepool {
      _1tf3our_BlockArgs_l2g8ke* args = [[_1tf3our_BlockArgs_l2g8ke alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      args.arg5 = arg5;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_l2g8ke* args = [[_1tf3our_BlockArgs_l2g8ke alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      args.arg5 = arg5;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

typedef void  (^_ProtocolTrampoline_8)(void * sel, id arg1, id arg2, id arg3, id arg4, id arg5);
__attribute__((visibility("default"))) __attribute__((used))
void  _1tf3our_protocolTrampoline_l2g8ke(id target, void * sel, id arg1, id arg2, id arg3, id arg4, id arg5) {
  return ((_ProtocolTrampoline_8)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4, arg5);
}

__attribute__((visibility("default")))
@interface _1tf3our_BlockArgs_1lx650f : NSObject
@property (copy) id block;
@property void * arg0;
@property (strong) id arg1;
@property (strong) id arg2;
@property NSURLSessionWebSocketCloseCode arg3;
@property (strong) id arg4;
@end
@implementation _1tf3our_BlockArgs_1lx650f
@end

typedef void  (^_ListenerTrampoline_16)(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_16 _1tf3our_wrapListenerBlock_1lx650f(
    int64_t port, DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  __block __weak _ListenerTrampoline_16 weakSelfBlock = nil;
  _ListenerTrampoline_16 strongSelfBlock = [^void(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4) {
    @autoreleasepool {
      _1tf3our_BlockArgs_1lx650f* args = [[_1tf3our_BlockArgs_1lx650f alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      ctx->invokeListenerPortBlock(port, (__bridge_retained void*)args);
    }
  } copy];
  weakSelfBlock = strongSelfBlock;
  return strongSelfBlock;
}

typedef void  (^_BlockingTrampoline_16)(void * waiter, void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_16 _1tf3our_wrapBlockingBlock_1lx650f(int64_t port, DOBJC_Context* ctx,
    void (*directInvoke)(void*)) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, _ListenerTrampoline_16, ^void(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4), {
    @autoreleasepool {
      _1tf3our_BlockArgs_1lx650f* args = [[_1tf3our_BlockArgs_1lx650f alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      directInvoke((__bridge_retained void*)args);
    }
  }, {
    @autoreleasepool {
      _1tf3our_BlockArgs_1lx650f* args = [[_1tf3our_BlockArgs_1lx650f alloc] init];
      args.block = weakSelfBlock;
      args.arg0 = arg0;
      args.arg1 = arg1;
      args.arg2 = arg2;
      args.arg3 = arg3;
      args.arg4 = arg4;
      ctx->invokeBlockingPortBlock(port, (__bridge_retained void*)args, waiter);
    }
  });
}

typedef void  (^_ProtocolTrampoline_9)(void * sel, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
void  _1tf3our_protocolTrampoline_1lx650f(id target, void * sel, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4) {
  return ((_ProtocolTrampoline_9)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4);
}
#undef BLOCKING_BLOCK_IMPL

#pragma clang diagnostic pop
