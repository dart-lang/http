#include <stdint.h>

#import "../../../../../../../System/Volumes/Data/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSArray.h"
#import "../../../../../../../System/Volumes/Data/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSData.h"
#import "../../../../../../../System/Volumes/Data/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSDictionary.h"
#import "../../../../../../../System/Volumes/Data/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSURLCache.h"
#import "../../../../../../../System/Volumes/Data/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSURLRequest.h"
#import "../../../../../../../System/Volumes/Data/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSURLSession.h"
#import "../../../../../../../System/Volumes/Data/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSURL.h"
#import "../../../../../../../System/Volumes/Data/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSProgress.h"
#import "../../../../../../../System/Volumes/Data/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSURLResponse.h"
#import "../../../../../../../System/Volumes/Data/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSHTTPCookieStorage.h"
#import "../../../../../../../System/Volumes/Data/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSOperation.h"
#import "../../../../../../../System/Volumes/Data/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSError.h"
#import "../../../../../../../System/Volumes/Data/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Foundation.framework/Versions/C/Headers/NSDictionary.h"

#include "CUPHTTPClientDelegate.h"
#include "CUPHTTPForwardedDelegate.h"
#include "CUPHTTPCompletionHelper.h"
#include "CUPHTTPStreamToNSInputStreamAdapter.h"

typedef void  (^ListenerBlock)(void * , NSCoder* );
ListenerBlock wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSCoder(ListenerBlock block) {
  ListenerBlock wrapper = [^void(void * arg0, NSCoder* arg1) {
    block(arg0, [arg1 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock1)(NSCachedURLResponse*  _Nullable );
ListenerBlock1 wrapListenerBlock_ObjCBlock_ffiVoid_NSCachedURLResponse(ListenerBlock1 block) {
  ListenerBlock1 wrapper = [^void(NSCachedURLResponse*  _Nullable arg0) {
    block([arg0 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock2)(NSNotification* );
ListenerBlock2 wrapListenerBlock_ObjCBlock_ffiVoid_NSNotification(ListenerBlock2 block) {
  ListenerBlock2 wrapper = [^void(NSNotification* arg0) {
    block([arg0 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock3)(NSArray*  _Nullable );
ListenerBlock3 wrapListenerBlock_ObjCBlock_ffiVoid_NSArray(ListenerBlock3 block) {
  ListenerBlock3 wrapper = [^void(NSArray*  _Nullable arg0) {
    block([arg0 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock4)(struct sec_protocol_metadata * , struct dispatch_data_s * , void  (^)(struct dispatch_data_s * ));
ListenerBlock4 wrapListenerBlock_ObjCBlock_ffiVoid_secprotocolmetadatat_dispatchdatat_secprotocolpresharedkeyselectioncompletet(ListenerBlock4 block) {
  ListenerBlock4 wrapper = [^void(struct sec_protocol_metadata * arg0, struct dispatch_data_s * arg1, void  (^arg2)(struct dispatch_data_s * )) {
    block(arg0, arg1, [arg2 copy]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock5)(struct sec_protocol_metadata * , void  (^)());
ListenerBlock5 wrapListenerBlock_ObjCBlock_ffiVoid_secprotocolmetadatat_secprotocolkeyupdatecompletet(ListenerBlock5 block) {
  ListenerBlock5 wrapper = [^void(struct sec_protocol_metadata * arg0, void  (^arg1)()) {
    block(arg0, [arg1 copy]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock6)(struct sec_protocol_metadata * , void  (^)(struct sec_identity * ));
ListenerBlock6 wrapListenerBlock_ObjCBlock_ffiVoid_secprotocolmetadatat_secprotocolchallengecompletet(ListenerBlock6 block) {
  ListenerBlock6 wrapper = [^void(struct sec_protocol_metadata * arg0, void  (^arg1)(struct sec_identity * )) {
    block(arg0, [arg1 copy]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock7)(struct sec_protocol_metadata * , struct sec_trust * , void  (^)(BOOL ));
ListenerBlock7 wrapListenerBlock_ObjCBlock_ffiVoid_secprotocolmetadatat_sectrustt_secprotocolverifycompletet(ListenerBlock7 block) {
  ListenerBlock7 wrapper = [^void(struct sec_protocol_metadata * arg0, struct sec_trust * arg1, void  (^arg2)(BOOL )) {
    block(arg0, arg1, [arg2 copy]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock8)(NSArray* , NSArray* , NSArray* );
ListenerBlock8 wrapListenerBlock_ObjCBlock_ffiVoid_NSArray_NSArray_NSArray(ListenerBlock8 block) {
  ListenerBlock8 wrapper = [^void(NSArray* arg0, NSArray* arg1, NSArray* arg2) {
    block([arg0 retain], [arg1 retain], [arg2 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock10)(NSData*  _Nullable );
ListenerBlock10 wrapListenerBlock_ObjCBlock_ffiVoid_NSData(ListenerBlock10 block) {
  ListenerBlock10 wrapper = [^void(NSData*  _Nullable arg0) {
    block([arg0 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock11)(NSData* , BOOL , NSError*  _Nullable );
ListenerBlock11 wrapListenerBlock_ObjCBlock_ffiVoid_NSData_bool_NSError(ListenerBlock11 block) {
  ListenerBlock11 wrapper = [^void(NSData* arg0, BOOL arg1, NSError*  _Nullable arg2) {
    block([arg0 retain], arg1, [arg2 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock12)(NSError*  _Nullable );
ListenerBlock12 wrapListenerBlock_ObjCBlock_ffiVoid_NSError(ListenerBlock12 block) {
  ListenerBlock12 wrapper = [^void(NSError*  _Nullable arg0) {
    block([arg0 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock13)(NSURLSessionWebSocketMessage*  _Nullable , NSError*  _Nullable );
ListenerBlock13 wrapListenerBlock_ObjCBlock_ffiVoid_NSURLSessionWebSocketMessage_NSError(ListenerBlock13 block) {
  ListenerBlock13 wrapper = [^void(NSURLSessionWebSocketMessage*  _Nullable arg0, NSError*  _Nullable arg1) {
    block([arg0 retain], [arg1 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock14)(NSData*  _Nullable , NSURLResponse*  _Nullable , NSError*  _Nullable );
ListenerBlock14 wrapListenerBlock_ObjCBlock_ffiVoid_NSData_NSURLResponse_NSError(ListenerBlock14 block) {
  ListenerBlock14 wrapper = [^void(NSData*  _Nullable arg0, NSURLResponse*  _Nullable arg1, NSError*  _Nullable arg2) {
    block([arg0 retain], [arg1 retain], [arg2 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock15)(NSURL*  _Nullable , NSURLResponse*  _Nullable , NSError*  _Nullable );
ListenerBlock15 wrapListenerBlock_ObjCBlock_ffiVoid_NSURL_NSURLResponse_NSError(ListenerBlock15 block) {
  ListenerBlock15 wrapper = [^void(NSURL*  _Nullable arg0, NSURLResponse*  _Nullable arg1, NSError*  _Nullable arg2) {
    block([arg0 retain], [arg1 retain], [arg2 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock16)(void * , NSURLSession* , NSError*  _Nullable );
ListenerBlock16 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSError(ListenerBlock16 block) {
  ListenerBlock16 wrapper = [^void(void * arg0, NSURLSession* arg1, NSError*  _Nullable arg2) {
    block(arg0, [arg1 retain], [arg2 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock17)(NSURLSessionAuthChallengeDisposition , NSURLCredential*  _Nullable );
ListenerBlock17 wrapListenerBlock_ObjCBlock_ffiVoid_NSURLSessionAuthChallengeDisposition_NSURLCredential(ListenerBlock17 block) {
  ListenerBlock17 wrapper = [^void(NSURLSessionAuthChallengeDisposition arg0, NSURLCredential*  _Nullable arg1) {
    block(arg0, [arg1 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock18)(void * , NSURLSession* , NSURLAuthenticationChallenge* , void  (^)(NSURLSessionAuthChallengeDisposition , NSURLCredential*  _Nullable ));
ListenerBlock18 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLAuthenticationChallenge_ffiVoidNSURLSessionAuthChallengeDispositionNSURLCredential(ListenerBlock18 block) {
  ListenerBlock18 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLAuthenticationChallenge* arg2, void  (^arg3)(NSURLSessionAuthChallengeDisposition , NSURLCredential*  _Nullable )) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 copy]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock19)(void * , NSURLSession* );
ListenerBlock19 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession(ListenerBlock19 block) {
  ListenerBlock19 wrapper = [^void(void * arg0, NSURLSession* arg1) {
    block(arg0, [arg1 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock20)(void * , NSURLSession* , NSURLSessionTask* );
ListenerBlock20 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask(ListenerBlock20 block) {
  ListenerBlock20 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2) {
    block(arg0, [arg1 retain], [arg2 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock21)(NSURLSessionDelayedRequestDisposition , NSURLRequest*  _Nullable );
ListenerBlock21 wrapListenerBlock_ObjCBlock_ffiVoid_NSURLSessionDelayedRequestDisposition_NSURLRequest(ListenerBlock21 block) {
  ListenerBlock21 wrapper = [^void(NSURLSessionDelayedRequestDisposition arg0, NSURLRequest*  _Nullable arg1) {
    block(arg0, [arg1 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock22)(void * , NSURLSession* , NSURLSessionTask* , NSURLRequest* , void  (^)(NSURLSessionDelayedRequestDisposition , NSURLRequest*  _Nullable ));
ListenerBlock22 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_NSURLRequest_ffiVoidNSURLSessionDelayedRequestDispositionNSURLRequest(ListenerBlock22 block) {
  ListenerBlock22 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, NSURLRequest* arg3, void  (^arg4)(NSURLSessionDelayedRequestDisposition , NSURLRequest*  _Nullable )) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain], [arg4 copy]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock23)(NSURLRequest*  _Nullable );
ListenerBlock23 wrapListenerBlock_ObjCBlock_ffiVoid_NSURLRequest(ListenerBlock23 block) {
  ListenerBlock23 wrapper = [^void(NSURLRequest*  _Nullable arg0) {
    block([arg0 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock24)(void * , NSURLSession* , NSURLSessionTask* , NSHTTPURLResponse* , NSURLRequest* , void  (^)(NSURLRequest*  _Nullable ));
ListenerBlock24 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_NSHTTPURLResponse_NSURLRequest_ffiVoidNSURLRequest(ListenerBlock24 block) {
  ListenerBlock24 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, NSHTTPURLResponse* arg3, NSURLRequest* arg4, void  (^arg5)(NSURLRequest*  _Nullable )) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain], [arg4 retain], [arg5 copy]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock25)(void * , NSURLSession* , NSURLSessionTask* , NSURLAuthenticationChallenge* , void  (^)(NSURLSessionAuthChallengeDisposition , NSURLCredential*  _Nullable ));
ListenerBlock25 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_NSURLAuthenticationChallenge_ffiVoidNSURLSessionAuthChallengeDispositionNSURLCredential(ListenerBlock25 block) {
  ListenerBlock25 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, NSURLAuthenticationChallenge* arg3, void  (^arg4)(NSURLSessionAuthChallengeDisposition , NSURLCredential*  _Nullable )) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain], [arg4 copy]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock26)(NSInputStream*  _Nullable );
ListenerBlock26 wrapListenerBlock_ObjCBlock_ffiVoid_NSInputStream(ListenerBlock26 block) {
  ListenerBlock26 wrapper = [^void(NSInputStream*  _Nullable arg0) {
    block([arg0 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock27)(void * , NSURLSession* , NSURLSessionTask* , void  (^)(NSInputStream*  _Nullable ));
ListenerBlock27 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_ffiVoidNSInputStream(ListenerBlock27 block) {
  ListenerBlock27 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, void  (^arg3)(NSInputStream*  _Nullable )) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 copy]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock28)(void * , NSURLSession* , NSURLSessionTask* , int64_t , void  (^)(NSInputStream*  _Nullable ));
ListenerBlock28 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_Int64_ffiVoidNSInputStream(ListenerBlock28 block) {
  ListenerBlock28 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, int64_t arg3, void  (^arg4)(NSInputStream*  _Nullable )) {
    block(arg0, [arg1 retain], [arg2 retain], arg3, [arg4 copy]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock29)(void * , NSURLSession* , NSURLSessionTask* , int64_t , int64_t , int64_t );
ListenerBlock29 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_Int64_Int64_Int64(ListenerBlock29 block) {
  ListenerBlock29 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    block(arg0, [arg1 retain], [arg2 retain], arg3, arg4, arg5);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock30)(void * , NSURLSession* , NSURLSessionTask* , NSHTTPURLResponse* );
ListenerBlock30 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_NSHTTPURLResponse(ListenerBlock30 block) {
  ListenerBlock30 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, NSHTTPURLResponse* arg3) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock31)(void * , NSURLSession* , NSURLSessionTask* , NSURLSessionTaskMetrics* );
ListenerBlock31 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_NSURLSessionTaskMetrics(ListenerBlock31 block) {
  ListenerBlock31 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, NSURLSessionTaskMetrics* arg3) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock32)(void * , NSURLSession* , NSURLSessionTask* , NSError*  _Nullable );
ListenerBlock32 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionTask_NSError(ListenerBlock32 block) {
  ListenerBlock32 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionTask* arg2, NSError*  _Nullable arg3) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock33)(void * , NSURLSession* , NSURLSessionDataTask* , NSURLResponse* , void  (^)(NSURLSessionResponseDisposition ));
ListenerBlock33 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDataTask_NSURLResponse_ffiVoidNSURLSessionResponseDisposition(ListenerBlock33 block) {
  ListenerBlock33 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionDataTask* arg2, NSURLResponse* arg3, void  (^arg4)(NSURLSessionResponseDisposition )) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain], [arg4 copy]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock34)(void * , NSURLSession* , NSURLSessionDataTask* , NSURLSessionDownloadTask* );
ListenerBlock34 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDataTask_NSURLSessionDownloadTask(ListenerBlock34 block) {
  ListenerBlock34 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionDataTask* arg2, NSURLSessionDownloadTask* arg3) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock35)(void * , NSURLSession* , NSURLSessionDataTask* , NSURLSessionStreamTask* );
ListenerBlock35 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDataTask_NSURLSessionStreamTask(ListenerBlock35 block) {
  ListenerBlock35 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionDataTask* arg2, NSURLSessionStreamTask* arg3) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock36)(void * , NSURLSession* , NSURLSessionDataTask* , NSData* );
ListenerBlock36 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDataTask_NSData(ListenerBlock36 block) {
  ListenerBlock36 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionDataTask* arg2, NSData* arg3) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock37)(void * , NSURLSession* , NSURLSessionDataTask* , NSCachedURLResponse* , void  (^)(NSCachedURLResponse*  _Nullable ));
ListenerBlock37 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDataTask_NSCachedURLResponse_ffiVoidNSCachedURLResponse(ListenerBlock37 block) {
  ListenerBlock37 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionDataTask* arg2, NSCachedURLResponse* arg3, void  (^arg4)(NSCachedURLResponse*  _Nullable )) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain], [arg4 copy]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock38)(void * , NSURLSession* , NSURLSessionDownloadTask* , NSURL* );
ListenerBlock38 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDownloadTask_NSURL(ListenerBlock38 block) {
  ListenerBlock38 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionDownloadTask* arg2, NSURL* arg3) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock39)(void * , NSURLSession* , NSURLSessionDownloadTask* , int64_t , int64_t , int64_t );
ListenerBlock39 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDownloadTask_Int64_Int64_Int64(ListenerBlock39 block) {
  ListenerBlock39 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionDownloadTask* arg2, int64_t arg3, int64_t arg4, int64_t arg5) {
    block(arg0, [arg1 retain], [arg2 retain], arg3, arg4, arg5);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock40)(void * , NSURLSession* , NSURLSessionDownloadTask* , int64_t , int64_t );
ListenerBlock40 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionDownloadTask_Int64_Int64(ListenerBlock40 block) {
  ListenerBlock40 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionDownloadTask* arg2, int64_t arg3, int64_t arg4) {
    block(arg0, [arg1 retain], [arg2 retain], arg3, arg4);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock41)(void * , NSURLSession* , NSURLSessionStreamTask* );
ListenerBlock41 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionStreamTask(ListenerBlock41 block) {
  ListenerBlock41 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionStreamTask* arg2) {
    block(arg0, [arg1 retain], [arg2 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock42)(void * , NSURLSession* , NSURLSessionStreamTask* , NSInputStream* , NSOutputStream* );
ListenerBlock42 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionStreamTask_NSInputStream_NSOutputStream(ListenerBlock42 block) {
  ListenerBlock42 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionStreamTask* arg2, NSInputStream* arg3, NSOutputStream* arg4) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain], [arg4 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock43)(void * , NSURLSession* , NSURLSessionWebSocketTask* , NSString*  _Nullable );
ListenerBlock43 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionWebSocketTask_NSString(ListenerBlock43 block) {
  ListenerBlock43 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionWebSocketTask* arg2, NSString*  _Nullable arg3) {
    block(arg0, [arg1 retain], [arg2 retain], [arg3 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock44)(void * , NSURLSession* , NSURLSessionWebSocketTask* , NSURLSessionWebSocketCloseCode , NSData*  _Nullable );
ListenerBlock44 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSURLSession_NSURLSessionWebSocketTask_NSURLSessionWebSocketCloseCode_NSData(ListenerBlock44 block) {
  ListenerBlock44 wrapper = [^void(void * arg0, NSURLSession* arg1, NSURLSessionWebSocketTask* arg2, NSURLSessionWebSocketCloseCode arg3, NSData*  _Nullable arg4) {
    block(arg0, [arg1 retain], [arg2 retain], arg3, [arg4 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock45)(NSData*  _Nullable , NSError*  _Nullable );
ListenerBlock45 wrapListenerBlock_ObjCBlock_ffiVoid_NSData_NSError(ListenerBlock45 block) {
  ListenerBlock45 wrapper = [^void(NSData*  _Nullable arg0, NSError*  _Nullable arg1) {
    block([arg0 retain], [arg1 retain]);
  } copy];
  [block release];
  return wrapper;
}

typedef void  (^ListenerBlock49)(void * , NSStream* , NSStreamEvent );
ListenerBlock49 wrapListenerBlock_ObjCBlock_ffiVoid_ffiVoid_NSStream_NSStreamEvent(ListenerBlock49 block) {
  ListenerBlock49 wrapper = [^void(void * arg0, NSStream* arg1, NSStreamEvent arg2) {
    block(arg0, [arg1 retain], arg2);
  } copy];
  [block release];
  return wrapper;
}
