#include <stdint.h>
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
_ListenerTrampoline _NativeCupertinoHttp_wrapListenerBlock_1pl9qdv(_ListenerTrampoline block) NS_RETURNS_RETAINED {
  return ^void() {
    objc_retainBlock(block);
    block();
  };
}

typedef void  (^_ListenerTrampoline1)(void * arg0);
_ListenerTrampoline1 _NativeCupertinoHttp_wrapListenerBlock_ovsamd(_ListenerTrampoline1 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

Protocol* _NativeCupertinoHttp_NSObject() { return @protocol(NSObject); }

Protocol* _NativeCupertinoHttp_NSCopying() { return @protocol(NSCopying); }

Protocol* _NativeCupertinoHttp_NSMutableCopying() { return @protocol(NSMutableCopying); }

typedef void  (^_ListenerTrampoline2)(void * arg0, id arg1);
_ListenerTrampoline2 _NativeCupertinoHttp_wrapListenerBlock_wjovn7(_ListenerTrampoline2 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1));
  };
}

Protocol* _NativeCupertinoHttp_NSCoding() { return @protocol(NSCoding); }

Protocol* _NativeCupertinoHttp_NSSecureCoding() { return @protocol(NSSecureCoding); }

Protocol* _NativeCupertinoHttp_NSDiscardableContent() { return @protocol(NSDiscardableContent); }

typedef void  (^_ListenerTrampoline3)(id arg0);
_ListenerTrampoline3 _NativeCupertinoHttp_wrapListenerBlock_1jdvcbf(_ListenerTrampoline3 block) NS_RETURNS_RETAINED {
  return ^void(id arg0) {
    objc_retainBlock(block);
    block(objc_retain(arg0));
  };
}

Protocol* _NativeCupertinoHttp_NSProgressReporting() { return @protocol(NSProgressReporting); }

Protocol* _NativeCupertinoHttp_NSFastEnumeration() { return @protocol(NSFastEnumeration); }

typedef void  (^_ListenerTrampoline4)(id arg0, id arg1, BOOL * arg2);
_ListenerTrampoline4 _NativeCupertinoHttp_wrapListenerBlock_1krhfwz(_ListenerTrampoline4 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, BOOL * arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), arg2);
  };
}

Protocol* _NativeCupertinoHttp_OS_sec_object() { return @protocol(OS_sec_object); }

typedef void  (^_ListenerTrampoline5)(struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1);
_ListenerTrampoline5 _NativeCupertinoHttp_wrapListenerBlock_tg5tbv(_ListenerTrampoline5 block) NS_RETURNS_RETAINED {
  return ^void(struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_ListenerTrampoline6)(struct __CFRunLoopTimer * arg0);
_ListenerTrampoline6 _NativeCupertinoHttp_wrapListenerBlock_1dqvvol(_ListenerTrampoline6 block) NS_RETURNS_RETAINED {
  return ^void(struct __CFRunLoopTimer * arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

Protocol* _NativeCupertinoHttp_OS_os_workgroup_interval() { return @protocol(OS_os_workgroup_interval); }

Protocol* _NativeCupertinoHttp_OS_os_workgroup_parallel() { return @protocol(OS_os_workgroup_parallel); }

Protocol* _NativeCupertinoHttp_OS_dispatch_object() { return @protocol(OS_dispatch_object); }

Protocol* _NativeCupertinoHttp_OS_dispatch_queue() { return @protocol(OS_dispatch_queue); }

Protocol* _NativeCupertinoHttp_OS_dispatch_queue_global() { return @protocol(OS_dispatch_queue_global); }

Protocol* _NativeCupertinoHttp_OS_dispatch_queue_serial_executor() { return @protocol(OS_dispatch_queue_serial_executor); }

Protocol* _NativeCupertinoHttp_OS_dispatch_queue_serial() { return @protocol(OS_dispatch_queue_serial); }

Protocol* _NativeCupertinoHttp_OS_dispatch_queue_main() { return @protocol(OS_dispatch_queue_main); }

Protocol* _NativeCupertinoHttp_OS_dispatch_queue_concurrent() { return @protocol(OS_dispatch_queue_concurrent); }

typedef void  (^_ListenerTrampoline7)(size_t arg0);
_ListenerTrampoline7 _NativeCupertinoHttp_wrapListenerBlock_6enxqz(_ListenerTrampoline7 block) NS_RETURNS_RETAINED {
  return ^void(size_t arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

Protocol* _NativeCupertinoHttp_OS_dispatch_queue_attr() { return @protocol(OS_dispatch_queue_attr); }

Protocol* _NativeCupertinoHttp_OS_dispatch_source() { return @protocol(OS_dispatch_source); }

Protocol* _NativeCupertinoHttp_OS_dispatch_group() { return @protocol(OS_dispatch_group); }

Protocol* _NativeCupertinoHttp_OS_dispatch_semaphore() { return @protocol(OS_dispatch_semaphore); }

Protocol* _NativeCupertinoHttp_OS_dispatch_data() { return @protocol(OS_dispatch_data); }

typedef void  (^_ListenerTrampoline8)(id arg0, int arg1);
_ListenerTrampoline8 _NativeCupertinoHttp_wrapListenerBlock_qxvyq2(_ListenerTrampoline8 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, int arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1);
  };
}

Protocol* _NativeCupertinoHttp_OS_dispatch_io() { return @protocol(OS_dispatch_io); }

typedef void  (^_ListenerTrampoline9)(int arg0);
_ListenerTrampoline9 _NativeCupertinoHttp_wrapListenerBlock_9o8504(_ListenerTrampoline9 block) NS_RETURNS_RETAINED {
  return ^void(int arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_ListenerTrampoline10)(BOOL arg0, id arg1, int arg2);
_ListenerTrampoline10 _NativeCupertinoHttp_wrapListenerBlock_12a4qua(_ListenerTrampoline10 block) NS_RETURNS_RETAINED {
  return ^void(BOOL arg0, id arg1, int arg2) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), arg2);
  };
}

Protocol* _NativeCupertinoHttp_OS_dispatch_workloop() { return @protocol(OS_dispatch_workloop); }

typedef void  (^_ListenerTrampoline11)(struct __SecTrust * arg0, SecTrustResultType arg1);
_ListenerTrampoline11 _NativeCupertinoHttp_wrapListenerBlock_gwxhxt(_ListenerTrampoline11 block) NS_RETURNS_RETAINED {
  return ^void(struct __SecTrust * arg0, SecTrustResultType arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_ListenerTrampoline12)(struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2);
_ListenerTrampoline12 _NativeCupertinoHttp_wrapListenerBlock_k73ff5(_ListenerTrampoline12 block) NS_RETURNS_RETAINED {
  return ^void(struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2) {
    objc_retainBlock(block);
    block(arg0, arg1, arg2);
  };
}

Protocol* _NativeCupertinoHttp_OS_sec_trust() { return @protocol(OS_sec_trust); }

Protocol* _NativeCupertinoHttp_OS_sec_identity() { return @protocol(OS_sec_identity); }

Protocol* _NativeCupertinoHttp_OS_sec_certificate() { return @protocol(OS_sec_certificate); }

Protocol* _NativeCupertinoHttp_OS_sec_protocol_metadata() { return @protocol(OS_sec_protocol_metadata); }

typedef void  (^_ListenerTrampoline13)(uint16_t arg0);
_ListenerTrampoline13 _NativeCupertinoHttp_wrapListenerBlock_15f11yh(_ListenerTrampoline13 block) NS_RETURNS_RETAINED {
  return ^void(uint16_t arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_ListenerTrampoline14)(id arg0, id arg1);
_ListenerTrampoline14 _NativeCupertinoHttp_wrapListenerBlock_wjvic9(_ListenerTrampoline14 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1));
  };
}

Protocol* _NativeCupertinoHttp_OS_sec_protocol_options() { return @protocol(OS_sec_protocol_options); }

typedef void  (^_ListenerTrampoline15)(id arg0, id arg1, id arg2);
_ListenerTrampoline15 _NativeCupertinoHttp_wrapListenerBlock_91c9gi(_ListenerTrampoline15 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), objc_retainBlock(arg2));
  };
}

typedef void  (^_ListenerTrampoline16)(id arg0, id arg1);
_ListenerTrampoline16 _NativeCupertinoHttp_wrapListenerBlock_14pxqbs(_ListenerTrampoline16 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retainBlock(arg1));
  };
}

typedef void  (^_ListenerTrampoline17)(BOOL arg0);
_ListenerTrampoline17 _NativeCupertinoHttp_wrapListenerBlock_1s56lr9(_ListenerTrampoline17 block) NS_RETURNS_RETAINED {
  return ^void(BOOL arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_ListenerTrampoline18)(id arg0, id arg1, id arg2);
_ListenerTrampoline18 _NativeCupertinoHttp_wrapListenerBlock_1hcfngn(_ListenerTrampoline18 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^_ListenerTrampoline19)(void * arg0, id arg1, id arg2);
_ListenerTrampoline19 _NativeCupertinoHttp_wrapListenerBlock_ao4xm9(_ListenerTrampoline19 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^_ListenerTrampoline20)(NSURLSessionAuthChallengeDisposition arg0, id arg1);
_ListenerTrampoline20 _NativeCupertinoHttp_wrapListenerBlock_37btrl(_ListenerTrampoline20 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionAuthChallengeDisposition arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^_ListenerTrampoline21)(void * arg0, id arg1, id arg2, id arg3);
_ListenerTrampoline21 _NativeCupertinoHttp_wrapListenerBlock_12nszru(_ListenerTrampoline21 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retainBlock(arg3));
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionDelegate() { return @protocol(NSURLSessionDelegate); }

typedef void  (^_ListenerTrampoline22)(NSURLSessionDelayedRequestDisposition arg0, id arg1);
_ListenerTrampoline22 _NativeCupertinoHttp_wrapListenerBlock_mn1xu3(_ListenerTrampoline22 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionDelayedRequestDisposition arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^_ListenerTrampoline23)(void * arg0, id arg1, id arg2, id arg3, id arg4);
_ListenerTrampoline23 _NativeCupertinoHttp_wrapListenerBlock_1f43wec(_ListenerTrampoline23 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retainBlock(arg4));
  };
}

typedef void  (^_ListenerTrampoline24)(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5);
_ListenerTrampoline24 _NativeCupertinoHttp_wrapListenerBlock_13vswqm(_ListenerTrampoline24 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retain(arg4), objc_retainBlock(arg5));
  };
}

typedef void  (^_ListenerTrampoline25)(void * arg0, id arg1, id arg2, int64_t arg3, id arg4);
_ListenerTrampoline25 _NativeCupertinoHttp_wrapListenerBlock_qm01og(_ListenerTrampoline25 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retainBlock(arg4));
  };
}

typedef void  (^_ListenerTrampoline26)(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5);
_ListenerTrampoline26 _NativeCupertinoHttp_wrapListenerBlock_1uuez7b(_ListenerTrampoline26 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4, arg5);
  };
}

typedef void  (^_ListenerTrampoline27)(void * arg0, id arg1, id arg2, id arg3);
_ListenerTrampoline27 _NativeCupertinoHttp_wrapListenerBlock_1r3kn8f(_ListenerTrampoline27 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionTaskDelegate() { return @protocol(NSURLSessionTaskDelegate); }

typedef void  (^_ListenerTrampoline28)(NSURLSessionResponseDisposition arg0);
_ListenerTrampoline28 _NativeCupertinoHttp_wrapListenerBlock_16sve1d(_ListenerTrampoline28 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionResponseDisposition arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionDataDelegate() { return @protocol(NSURLSessionDataDelegate); }

typedef void  (^_ListenerTrampoline29)(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4);
_ListenerTrampoline29 _NativeCupertinoHttp_wrapListenerBlock_9qxjkl(_ListenerTrampoline29 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4);
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionDownloadDelegate() { return @protocol(NSURLSessionDownloadDelegate); }

typedef void  (^_ListenerTrampoline30)(void * arg0, id arg1, id arg2, id arg3, id arg4);
_ListenerTrampoline30 _NativeCupertinoHttp_wrapListenerBlock_62mtml(_ListenerTrampoline30 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retain(arg4));
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionStreamDelegate() { return @protocol(NSURLSessionStreamDelegate); }

typedef void  (^_ListenerTrampoline31)(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4);
_ListenerTrampoline31 _NativeCupertinoHttp_wrapListenerBlock_3lo3bb(_ListenerTrampoline31 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retain(arg4));
  };
}

Protocol* _NativeCupertinoHttp_NSURLSessionWebSocketDelegate() { return @protocol(NSURLSessionWebSocketDelegate); }

typedef void  (^_ListenerTrampoline32)(id arg0, unsigned long arg1, BOOL * arg2);
_ListenerTrampoline32 _NativeCupertinoHttp_wrapListenerBlock_16ko9u(_ListenerTrampoline32 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, unsigned long arg1, BOOL * arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1, arg2);
  };
}

Protocol* _NativeCupertinoHttp_NSItemProviderWriting() { return @protocol(NSItemProviderWriting); }

Protocol* _NativeCupertinoHttp_NSItemProviderReading() { return @protocol(NSItemProviderReading); }

typedef void  (^_ListenerTrampoline33)(id arg0, id arg1, id arg2);
_ListenerTrampoline33 _NativeCupertinoHttp_wrapListenerBlock_1j2nt86(_ListenerTrampoline33 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retainBlock(arg0), objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^_ListenerTrampoline34)(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3);
_ListenerTrampoline34 _NativeCupertinoHttp_wrapListenerBlock_8wbg7l(_ListenerTrampoline34 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, struct _NSRange arg1, struct _NSRange arg2, BOOL * arg3) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1, arg2, arg3);
  };
}

typedef void  (^_ListenerTrampoline35)(id arg0, BOOL * arg1);
_ListenerTrampoline35 _NativeCupertinoHttp_wrapListenerBlock_148br51(_ListenerTrampoline35 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, BOOL * arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1);
  };
}

typedef void  (^_ListenerTrampoline36)(unsigned short * arg0, unsigned long arg1);
_ListenerTrampoline36 _NativeCupertinoHttp_wrapListenerBlock_vhbh5h(_ListenerTrampoline36 block) NS_RETURNS_RETAINED {
  return ^void(unsigned short * arg0, unsigned long arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_ListenerTrampoline37)(void * arg0, unsigned long arg1);
_ListenerTrampoline37 _NativeCupertinoHttp_wrapListenerBlock_zuf90e(_ListenerTrampoline37 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, unsigned long arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

Protocol* _NativeCupertinoHttp_NSURLHandleClient() { return @protocol(NSURLHandleClient); }

Protocol* _NativeCupertinoHttp_NSLocking() { return @protocol(NSLocking); }

typedef void  (^_ListenerTrampoline38)(id arg0, id arg1, id arg2, id arg3);
_ListenerTrampoline38 _NativeCupertinoHttp_wrapListenerBlock_4ya7yd(_ListenerTrampoline38 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}
