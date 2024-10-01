#include <stdint.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSURLCache.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSURLSession.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSProgress.h>
#import <Foundation/NSURLResponse.h>
#import <Foundation/NSHTTPCookieStorage.h>
#import <Foundation/NSOperation.h>
#import <Foundation/NSError.h>
#import <Foundation/NSDictionary.h>

#if !__has_feature(objc_arc)
#error "This file must be compiled with ARC enabled"
#endif

id objc_retain(id);
id objc_retainBlock(id);

typedef void  (^_ListenerTrampoline)();
_ListenerTrampoline _wrapListenerBlock_ksby9f(_ListenerTrampoline block) NS_RETURNS_RETAINED {
  return ^void() {
    objc_retainBlock(block);
    block();
  };
}

typedef void  (^_ListenerTrampoline1)(void * arg0);
_ListenerTrampoline1 _wrapListenerBlock_hepzs(_ListenerTrampoline1 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_ListenerTrampoline2)(void * arg0, id arg1);
_ListenerTrampoline2 _wrapListenerBlock_sjfpmz(_ListenerTrampoline2 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^_ListenerTrampoline3)(id arg0);
_ListenerTrampoline3 _wrapListenerBlock_ukcdfq(_ListenerTrampoline3 block) NS_RETURNS_RETAINED {
  return ^void(id arg0) {
    objc_retainBlock(block);
    block(objc_retain(arg0));
  };
}

typedef void  (^_ListenerTrampoline4)(struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1);
_ListenerTrampoline4 _wrapListenerBlock_ttt6u1(_ListenerTrampoline4 block) NS_RETURNS_RETAINED {
  return ^void(struct __CFRunLoopObserver * arg0, CFRunLoopActivity arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_ListenerTrampoline5)(struct __CFRunLoopTimer * arg0);
_ListenerTrampoline5 _wrapListenerBlock_1txhfzs(_ListenerTrampoline5 block) NS_RETURNS_RETAINED {
  return ^void(struct __CFRunLoopTimer * arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_ListenerTrampoline6)(size_t arg0);
_ListenerTrampoline6 _wrapListenerBlock_1hmngv6(_ListenerTrampoline6 block) NS_RETURNS_RETAINED {
  return ^void(size_t arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_ListenerTrampoline7)(id arg0, int arg1);
_ListenerTrampoline7 _wrapListenerBlock_108ugvk(_ListenerTrampoline7 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, int arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1);
  };
}

typedef void  (^_ListenerTrampoline8)(int arg0);
_ListenerTrampoline8 _wrapListenerBlock_1afulej(_ListenerTrampoline8 block) NS_RETURNS_RETAINED {
  return ^void(int arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_ListenerTrampoline9)(BOOL arg0, id arg1, int arg2);
_ListenerTrampoline9 _wrapListenerBlock_elldw5(_ListenerTrampoline9 block) NS_RETURNS_RETAINED {
  return ^void(BOOL arg0, id arg1, int arg2) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), arg2);
  };
}

typedef void  (^_ListenerTrampoline10)(struct __SecTrust * arg0, SecTrustResultType arg1);
_ListenerTrampoline10 _wrapListenerBlock_129ffij(_ListenerTrampoline10 block) NS_RETURNS_RETAINED {
  return ^void(struct __SecTrust * arg0, SecTrustResultType arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_ListenerTrampoline11)(struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2);
_ListenerTrampoline11 _wrapListenerBlock_1458n52(_ListenerTrampoline11 block) NS_RETURNS_RETAINED {
  return ^void(struct __SecTrust * arg0, BOOL arg1, struct __CFError * arg2) {
    objc_retainBlock(block);
    block(arg0, arg1, arg2);
  };
}

typedef void  (^_ListenerTrampoline12)(uint16_t arg0);
_ListenerTrampoline12 _wrapListenerBlock_yo3tv0(_ListenerTrampoline12 block) NS_RETURNS_RETAINED {
  return ^void(uint16_t arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_ListenerTrampoline13)(id arg0, id arg1);
_ListenerTrampoline13 _wrapListenerBlock_1tjlcwl(_ListenerTrampoline13 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1));
  };
}

typedef void  (^_ListenerTrampoline14)(id arg0, id arg1, id arg2);
_ListenerTrampoline14 _wrapListenerBlock_10t0qpd(_ListenerTrampoline14 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), objc_retainBlock(arg2));
  };
}

typedef void  (^_ListenerTrampoline15)(id arg0, id arg1);
_ListenerTrampoline15 _wrapListenerBlock_cmbt6k(_ListenerTrampoline15 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retainBlock(arg1));
  };
}

typedef void  (^_ListenerTrampoline16)(BOOL arg0);
_ListenerTrampoline16 _wrapListenerBlock_117qins(_ListenerTrampoline16 block) NS_RETURNS_RETAINED {
  return ^void(BOOL arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_ListenerTrampoline17)(id arg0, id arg1, id arg2);
_ListenerTrampoline17 _wrapListenerBlock_tenbla(_ListenerTrampoline17 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^_ListenerTrampoline18)(id arg0, BOOL arg1, id arg2);
_ListenerTrampoline18 _wrapListenerBlock_hfhq9m(_ListenerTrampoline18 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, BOOL arg1, id arg2) {
    objc_retainBlock(block);
    block(objc_retain(arg0), arg1, objc_retain(arg2));
  };
}

typedef void  (^_ListenerTrampoline19)(void * arg0, id arg1, id arg2);
_ListenerTrampoline19 _wrapListenerBlock_tm2na8(_ListenerTrampoline19 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^_ListenerTrampoline20)(NSURLSessionAuthChallengeDisposition arg0, id arg1);
_ListenerTrampoline20 _wrapListenerBlock_1najo2h(_ListenerTrampoline20 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionAuthChallengeDisposition arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^_ListenerTrampoline21)(void * arg0, id arg1, id arg2, id arg3);
_ListenerTrampoline21 _wrapListenerBlock_1wmulza(_ListenerTrampoline21 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retainBlock(arg3));
  };
}

typedef void  (^_ListenerTrampoline22)(NSURLSessionDelayedRequestDisposition arg0, id arg1);
_ListenerTrampoline22 _wrapListenerBlock_wnmjgj(_ListenerTrampoline22 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionDelayedRequestDisposition arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^_ListenerTrampoline23)(void * arg0, id arg1, id arg2, id arg3, id arg4);
_ListenerTrampoline23 _wrapListenerBlock_1nnj9ov(_ListenerTrampoline23 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retainBlock(arg4));
  };
}

typedef void  (^_ListenerTrampoline24)(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5);
_ListenerTrampoline24 _wrapListenerBlock_dmve6(_ListenerTrampoline24 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4, id arg5) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retain(arg4), objc_retainBlock(arg5));
  };
}

typedef void  (^_ListenerTrampoline25)(void * arg0, id arg1, id arg2, int64_t arg3, id arg4);
_ListenerTrampoline25 _wrapListenerBlock_qxeqyf(_ListenerTrampoline25 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retainBlock(arg4));
  };
}

typedef void  (^_ListenerTrampoline26)(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5);
_ListenerTrampoline26 _wrapListenerBlock_jzggzf(_ListenerTrampoline26 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4, arg5);
  };
}

typedef void  (^_ListenerTrampoline27)(void * arg0, id arg1, id arg2, id arg3);
_ListenerTrampoline27 _wrapListenerBlock_1a6kixf(_ListenerTrampoline27 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

typedef void  (^_ListenerTrampoline28)(NSURLSessionResponseDisposition arg0);
_ListenerTrampoline28 _wrapListenerBlock_ci81hw(_ListenerTrampoline28 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionResponseDisposition arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_ListenerTrampoline29)(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4);
_ListenerTrampoline29 _wrapListenerBlock_1wl7fts(_ListenerTrampoline29 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, int64_t arg3, int64_t arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4);
  };
}

typedef void  (^_ListenerTrampoline30)(void * arg0, id arg1, id arg2, id arg3, id arg4);
_ListenerTrampoline30 _wrapListenerBlock_no6pyg(_ListenerTrampoline30 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retain(arg4));
  };
}

typedef void  (^_ListenerTrampoline31)(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4);
_ListenerTrampoline31 _wrapListenerBlock_10hgvcc(_ListenerTrampoline31 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, NSURLSessionWebSocketCloseCode arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retain(arg4));
  };
}

typedef void  (^_ListenerTrampoline32)(unsigned short * arg0, unsigned long arg1);
_ListenerTrampoline32 _wrapListenerBlock_zpobzb(_ListenerTrampoline32 block) NS_RETURNS_RETAINED {
  return ^void(unsigned short * arg0, unsigned long arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_ListenerTrampoline33)(void * arg0, unsigned long arg1);
_ListenerTrampoline33 _wrapListenerBlock_vzqe8w(_ListenerTrampoline33 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, unsigned long arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}
