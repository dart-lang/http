#include <stdint.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSURLCache.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSURLSession.h>
#import <Foundation/NSURLHandle.h>
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

typedef void  (^ListenerBlock)(void * , NSCoder* );
ListenerBlock wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSCoder(ListenerBlock block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSCoder* arg1) {
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^ListenerBlock1)(NSCachedURLResponse* );
ListenerBlock1 wrapListenerBlock_ObjCBlock_ffiVoid_NSCachedURLResponse(ListenerBlock1 block) NS_RETURNS_RETAINED {
  return ^void(NSCachedURLResponse* arg0) {
    block(objc_retain(arg0));
  };
}

typedef void  (^ListenerBlock2)(NSNotification* );
ListenerBlock2 wrapListenerBlock_ObjCBlock_ffiVoid_NSNotification(ListenerBlock2 block) NS_RETURNS_RETAINED {
  return ^void(NSNotification* arg0) {
    block(objc_retain(arg0));
  };
}

typedef void  (^ListenerBlock3)(NSArray* );
ListenerBlock3 wrapListenerBlock_ObjCBlock_ffiVoid_NSArray(ListenerBlock3 block) NS_RETURNS_RETAINED {
  return ^void(NSArray* arg0) {
    block(objc_retain(arg0));
  };
}

typedef void  (^ListenerBlock4)(NSObject* , int );
ListenerBlock4 wrapListenerBlock_ObjCBlock_ffiVoid_dispatchdatat_ffiInt(ListenerBlock4 block) NS_RETURNS_RETAINED {
  return ^void(NSObject* arg0, int arg1) {
    block(objc_retain(arg0), arg1);
  };
}

typedef void  (^ListenerBlock5)(BOOL , NSObject* , int );
ListenerBlock5 wrapListenerBlock_ObjCBlock_ffiVoid_bool_dispatchdatat_ffiInt(ListenerBlock5 block) NS_RETURNS_RETAINED {
  return ^void(BOOL arg0, NSObject* arg1, int arg2) {
    block(arg0, objc_retain(arg1), arg2);
  };
}

typedef void  (^ListenerBlock6)(NSObject* );
ListenerBlock6 wrapListenerBlock_ObjCBlock_ffiVoid_seccertificatet(ListenerBlock6 block) NS_RETURNS_RETAINED {
  return ^void(NSObject* arg0) {
    block(objc_retain(arg0));
  };
}

typedef void  (^ListenerBlock7)(NSObject* , NSObject* );
ListenerBlock7 wrapListenerBlock_ObjCBlock_ffiVoid_dispatchdatat_dispatchdatat(ListenerBlock7 block) NS_RETURNS_RETAINED {
  return ^void(NSObject* arg0, NSObject* arg1) {
    block(objc_retain(arg0), objc_retain(arg1));
  };
}

typedef void  (^ListenerBlock8)(NSObject* , NSObject* , void  (^)(NSObject* ));
ListenerBlock8 wrapListenerBlock_ObjCBlock_ffiVoid_secprotocolmetadatat_dispatchdatat_secprotocolpresharedkeyselectioncompletet(ListenerBlock8 block) NS_RETURNS_RETAINED {
  return ^void(NSObject* arg0, NSObject* arg1, void  (^arg2)(NSObject* )) {
    block(objc_retain(arg0), objc_retain(arg1), objc_retainBlock(arg2));
  };
}

typedef void  (^ListenerBlock9)(NSObject* , void  (^)());
ListenerBlock9 wrapListenerBlock_ObjCBlock_ffiVoid_secprotocolmetadatat_secprotocolkeyupdatecompletet(ListenerBlock9 block) NS_RETURNS_RETAINED {
  return ^void(NSObject* arg0, void  (^arg1)()) {
    block(objc_retain(arg0), objc_retainBlock(arg1));
  };
}

typedef void  (^ListenerBlock10)(NSObject* , void  (^)(NSObject* ));
ListenerBlock10 wrapListenerBlock_ObjCBlock_ffiVoid_secprotocolmetadatat_secprotocolchallengecompletet(ListenerBlock10 block) NS_RETURNS_RETAINED {
  return ^void(NSObject* arg0, void  (^arg1)(NSObject* )) {
    block(objc_retain(arg0), objc_retainBlock(arg1));
  };
}

typedef void  (^ListenerBlock11)(NSObject* , NSObject* , void  (^)(BOOL ));
ListenerBlock11 wrapListenerBlock_ObjCBlock_ffiVoid_secprotocolmetadatat_sectrustt_secprotocolverifycompletet(ListenerBlock11 block) NS_RETURNS_RETAINED {
  return ^void(NSObject* arg0, NSObject* arg1, void  (^arg2)(BOOL )) {
    block(objc_retain(arg0), objc_retain(arg1), objc_retainBlock(arg2));
  };
}

typedef void  (^ListenerBlock12)(NSArray* , NSArray* , NSArray* );
ListenerBlock12 wrapListenerBlock_ObjCBlock_ffiVoid_NSArray_NSArray_NSArray(ListenerBlock12 block) NS_RETURNS_RETAINED {
  return ^void(NSArray* arg0, NSArray* arg1, NSArray* arg2) {
    block(objc_retain(arg0), objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^ListenerBlock13)(NSArray* );
ListenerBlock13 wrapListenerBlock_ObjCBlock_ffiVoid_NSArray1(ListenerBlock13 block) NS_RETURNS_RETAINED {
  return ^void(NSArray* arg0) {
    block(objc_retain(arg0));
  };
}

typedef void  (^ListenerBlock14)(NSData* );
ListenerBlock14 wrapListenerBlock_ObjCBlock_ffiVoid_NSData(ListenerBlock14 block) NS_RETURNS_RETAINED {
  return ^void(NSData* arg0) {
    block(objc_retain(arg0));
  };
}

typedef void  (^ListenerBlock15)(NSData* , BOOL , NSError* );
ListenerBlock15 wrapListenerBlock_ObjCBlock_ffiVoid_NSData_bool_NSError(ListenerBlock15 block) NS_RETURNS_RETAINED {
  return ^void(NSData* arg0, BOOL arg1, NSError* arg2) {
    block(objc_retain(arg0), arg1, objc_retain(arg2));
  };
}

typedef void  (^ListenerBlock16)(NSError* );
ListenerBlock16 wrapListenerBlock_ObjCBlock_ffiVoid_NSError(ListenerBlock16 block) NS_RETURNS_RETAINED {
  return ^void(NSError* arg0) {
    block(objc_retain(arg0));
  };
}

typedef void  (^ListenerBlock17)(NSURLSessionWebSocketMessage* , NSError* );
ListenerBlock17 wrapListenerBlock_ObjCBlock_ffiVoid_NSURLSessionWebSocketMessage_NSError(ListenerBlock17 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionWebSocketMessage* arg0, NSError* arg1) {
    block(objc_retain(arg0), objc_retain(arg1));
  };
}

typedef void  (^ListenerBlock18)(NSData* , NSURLResponse* , NSError* );
ListenerBlock18 wrapListenerBlock_ObjCBlock_ffiVoid_NSData_NSURLResponse_NSError(ListenerBlock18 block) NS_RETURNS_RETAINED {
  return ^void(NSData* arg0, NSURLResponse* arg1, NSError* arg2) {
    block(objc_retain(arg0), objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^ListenerBlock19)(NSURL* , NSURLResponse* , NSError* );
ListenerBlock19 wrapListenerBlock_ObjCBlock_ffiVoid_NSURL_NSURLResponse_NSError(ListenerBlock19 block) NS_RETURNS_RETAINED {
  return ^void(NSURL* arg0, NSURLResponse* arg1, NSError* arg2) {
    block(objc_retain(arg0), objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^ListenerBlock20)(void * , NSURLSession* , NSError* );
ListenerBlock20 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSError(ListenerBlock20 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSError* arg2) {
    block(arg0, objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^ListenerBlock21)(NSURLSessionAuthChallengeDisposition , NSURLCredential* );
ListenerBlock21 wrapListenerBlock_ObjCBlock_ffiVoid_NSURLSessionAuthChallengeDisposition_NSURLCredential(ListenerBlock21 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionAuthChallengeDisposition arg0, NSURLCredential* arg1) {
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^ListenerBlock22)(void * , NSURLSession* , NSURLAuthenticationChallenge* , void  (^)(NSURLSessionAuthChallengeDisposition , NSURLCredential* ));
ListenerBlock22 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLAuthenticationChallenge_ffiVoidNSURLSessionAuthChallengeDispositionNSURLCredential(ListenerBlock22 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLAuthenticationChallenge* arg2, void  (^arg3)(NSURLSessionAuthChallengeDisposition , NSURLCredential* )) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retainBlock(arg3));
  };
}

typedef void  (^ListenerBlock23)(void * , NSURLSession* );
ListenerBlock23 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession(ListenerBlock23 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1) {
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^ListenerBlock24)(void * , NSURLSession* , NSURLSessionTask* );
ListenerBlock24 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask(ListenerBlock24 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2) {
    block(arg0, objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^ListenerBlock25)(NSURLSessionDelayedRequestDisposition , NSURLRequest* );
ListenerBlock25 wrapListenerBlock_ObjCBlock_ffiVoid_NSURLSessionDelayedRequestDisposition_NSURLRequest(ListenerBlock25 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionDelayedRequestDisposition arg0, NSURLRequest* arg1) {
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^ListenerBlock26)(void * , NSURLSession* , NSURLSessionTask* , NSURLRequest* , void  (^)(NSURLSessionDelayedRequestDisposition , NSURLRequest* ));
ListenerBlock26 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_NSURLRequest_ffiVoidNSURLSessionDelayedRequestDispositionNSURLRequest(ListenerBlock26 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, NSURLRequest* arg3, void  (^arg4)(NSURLSessionDelayedRequestDisposition , NSURLRequest* )) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retainBlock(arg4));
  };
}

typedef void  (^ListenerBlock27)(NSURLRequest* );
ListenerBlock27 wrapListenerBlock_ObjCBlock_ffiVoid_NSURLRequest(ListenerBlock27 block) NS_RETURNS_RETAINED {
  return ^void(NSURLRequest* arg0) {
    block(objc_retain(arg0));
  };
}

typedef void  (^ListenerBlock28)(void * , NSURLSession* , NSURLSessionTask* , NSHTTPURLResponse* , NSURLRequest* , void  (^)(NSURLRequest* ));
ListenerBlock28 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_NSHTTPURLResponse_NSURLRequest_ffiVoidNSURLRequest(ListenerBlock28 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, NSHTTPURLResponse* arg3, NSURLRequest* arg4, void  (^arg5)(NSURLRequest* )) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retain(arg4), objc_retainBlock(arg5));
  };
}

typedef void  (^ListenerBlock29)(void * , NSURLSession* , NSURLSessionTask* , NSURLAuthenticationChallenge* , void  (^)(NSURLSessionAuthChallengeDisposition , NSURLCredential* ));
ListenerBlock29 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_NSURLAuthenticationChallenge_ffiVoidNSURLSessionAuthChallengeDispositionNSURLCredential(ListenerBlock29 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, NSURLAuthenticationChallenge* arg3, void  (^arg4)(NSURLSessionAuthChallengeDisposition , NSURLCredential* )) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retainBlock(arg4));
  };
}

typedef void  (^ListenerBlock30)(NSInputStream* );
ListenerBlock30 wrapListenerBlock_ObjCBlock_ffiVoid_NSInputStream(ListenerBlock30 block) NS_RETURNS_RETAINED {
  return ^void(NSInputStream* arg0) {
    block(objc_retain(arg0));
  };
}

typedef void  (^ListenerBlock31)(void * , NSURLSession* , NSURLSessionTask* , void  (^)(NSInputStream* ));
ListenerBlock31 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_ffiVoidNSInputStream(ListenerBlock31 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, void  (^arg3)(NSInputStream* )) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retainBlock(arg3));
  };
}

typedef void  (^ListenerBlock32)(void * , NSURLSession* , NSURLSessionTask* , int64_t , void  (^)(NSInputStream* ));
ListenerBlock32 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_Int64_ffiVoidNSInputStream(ListenerBlock32 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, int64_t arg3, void  (^arg4)(NSInputStream* )) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retainBlock(arg4));
  };
}

typedef void  (^ListenerBlock33)(void * , NSURLSession* , NSURLSessionTask* , int64_t , int64_t , int64_t );
ListenerBlock33 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_Int64_Int64_Int64(ListenerBlock33 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4, arg5);
  };
}

typedef void  (^ListenerBlock34)(void * , NSURLSession* , NSURLSessionTask* , NSHTTPURLResponse* );
ListenerBlock34 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_NSHTTPURLResponse(ListenerBlock34 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, NSHTTPURLResponse* arg3) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

typedef void  (^ListenerBlock35)(void * , NSURLSession* , NSURLSessionTask* , NSURLSessionTaskMetrics* );
ListenerBlock35 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_NSURLSessionTaskMetrics(ListenerBlock35 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, NSURLSessionTaskMetrics* arg3) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

typedef void  (^ListenerBlock36)(void * , NSURLSession* , NSURLSessionTask* , NSError* );
ListenerBlock36 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_NSError(ListenerBlock36 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, NSError* arg3) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

typedef void  (^ListenerBlock37)(void * , NSURLSession* , NSURLSessionDataTask* , NSURLResponse* , void  (^)(NSURLSessionResponseDisposition ));
ListenerBlock37 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDataTask_NSURLResponse_ffiVoidNSURLSessionResponseDisposition(ListenerBlock37 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionDataTask* arg2, NSURLResponse* arg3, void  (^arg4)(NSURLSessionResponseDisposition )) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retainBlock(arg4));
  };
}

typedef void  (^ListenerBlock38)(void * , NSURLSession* , NSURLSessionDataTask* , NSURLSessionDownloadTask* );
ListenerBlock38 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDataTask_NSURLSessionDownloadTask(ListenerBlock38 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionDataTask* arg2, NSURLSessionDownloadTask* arg3) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

typedef void  (^ListenerBlock39)(void * , NSURLSession* , NSURLSessionDataTask* , NSURLSessionStreamTask* );
ListenerBlock39 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDataTask_NSURLSessionStreamTask(ListenerBlock39 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionDataTask* arg2, NSURLSessionStreamTask* arg3) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

typedef void  (^ListenerBlock40)(void * , NSURLSession* , NSURLSessionDataTask* , NSData* );
ListenerBlock40 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDataTask_NSData(ListenerBlock40 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionDataTask* arg2, NSData* arg3) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

typedef void  (^ListenerBlock41)(void * , NSURLSession* , NSURLSessionDataTask* , NSCachedURLResponse* , void  (^)(NSCachedURLResponse* ));
ListenerBlock41 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDataTask_NSCachedURLResponse_ffiVoidNSCachedURLResponse(ListenerBlock41 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionDataTask* arg2, NSCachedURLResponse* arg3, void  (^arg4)(NSCachedURLResponse* )) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retainBlock(arg4));
  };
}

typedef void  (^ListenerBlock42)(void * , NSURLSession* , NSURLSessionDownloadTask* , NSURL* );
ListenerBlock42 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDownloadTask_NSURL(ListenerBlock42 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionDownloadTask* arg2, NSURL* arg3) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

typedef void  (^ListenerBlock43)(void * , NSURLSession* , NSURLSessionDownloadTask* , int64_t , int64_t , int64_t );
ListenerBlock43 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDownloadTask_Int64_Int64_Int64(ListenerBlock43 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionDownloadTask* arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4, arg5);
  };
}

typedef void  (^ListenerBlock44)(void * , NSURLSession* , NSURLSessionDownloadTask* , int64_t , int64_t );
ListenerBlock44 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDownloadTask_Int64_Int64(ListenerBlock44 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionDownloadTask* arg2, int64_t arg3, int64_t arg4) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, arg4);
  };
}

typedef void  (^ListenerBlock45)(void * , NSURLSession* , NSURLSessionStreamTask* );
ListenerBlock45 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionStreamTask(ListenerBlock45 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionStreamTask* arg2) {
    block(arg0, objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^ListenerBlock46)(void * , NSURLSession* , NSURLSessionStreamTask* , NSInputStream* , NSOutputStream* );
ListenerBlock46 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionStreamTask_NSInputStream_NSOutputStream(ListenerBlock46 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionStreamTask* arg2, NSInputStream* arg3, NSOutputStream* arg4) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3), objc_retain(arg4));
  };
}

typedef void  (^ListenerBlock47)(void * , NSURLSession* , NSURLSessionWebSocketTask* , NSString* );
ListenerBlock47 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionWebSocketTask_NSString(ListenerBlock47 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionWebSocketTask* arg2, NSString* arg3) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), objc_retain(arg3));
  };
}

typedef void  (^ListenerBlock48)(void * , NSURLSession* , NSURLSessionWebSocketTask* , NSURLSessionWebSocketCloseCode , NSData* );
ListenerBlock48 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionWebSocketTask_NSURLSessionWebSocketCloseCode_NSData(ListenerBlock48 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLSession* arg1, NSURLSessionWebSocketTask* arg2, NSURLSessionWebSocketCloseCode arg3, NSData* arg4) {
    block(arg0, objc_retain(arg1), objc_retain(arg2), arg3, objc_retain(arg4));
  };
}

typedef void  (^ListenerBlock49)(void * , NSURLHandle* , NSData* );
ListenerBlock49 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLHandle_NSData(ListenerBlock49 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLHandle* arg1, NSData* arg2) {
    block(arg0, objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^ListenerBlock50)(void * , NSURLHandle* );
ListenerBlock50 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLHandle(ListenerBlock50 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLHandle* arg1) {
    block(arg0, objc_retain(arg1));
  };
}

typedef void  (^ListenerBlock51)(void * , NSURLHandle* , NSString* );
ListenerBlock51 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLHandle_NSString(ListenerBlock51 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSURLHandle* arg1, NSString* arg2) {
    block(arg0, objc_retain(arg1), objc_retain(arg2));
  };
}

typedef void  (^ListenerBlock52)(NSData* , NSError* );
ListenerBlock52 wrapListenerBlock_ObjCBlock_ffiVoid_NSData_NSError(ListenerBlock52 block) NS_RETURNS_RETAINED {
  return ^void(NSData* arg0, NSError* arg1) {
    block(objc_retain(arg0), objc_retain(arg1));
  };
}
