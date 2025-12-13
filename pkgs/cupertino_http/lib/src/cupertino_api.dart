// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Provides access to the
/// [Foundation URL Loading System](https://developer.apple.com/documentation/foundation/url_loading_system).
///
/// For example:
/// ```
/// void main() {
///   final url = Uri.https('www.example.com', '/');
///   final session = URLSession.sharedSession();
///   final task = session.dataTaskWithCompletionHandler(
///     URLRequest.fromUrl(url),
///       (data, response, error) {
///     if (error == null) {
///       if (response != null && response.statusCode == 200) {
///         print(response);  // Do something with the response.
///         return;
///       }
///     }
///     print(error);  // Handle errors.
///   });
///   task.resume();
/// }
/// ```
library;

import 'dart:async';

import 'package:objective_c/objective_c.dart' as objc;

import 'native_cupertino_bindings.dart' as ncb;
import 'native_cupertino_bindings.dart'
    show
        NSHTTPCookieAcceptPolicy,
        NSURLRequestCachePolicy,
        NSURLRequestNetworkServiceType,
        NSURLSessionMultipathServiceType,
        NSURLSessionResponseDisposition,
        NSURLSessionTaskState,
        NSURLSessionWebSocketMessageType;

export 'native_cupertino_bindings.dart'
    show
        NSHTTPCookieAcceptPolicy,
        NSURLRequestCachePolicy,
        NSURLRequestNetworkServiceType,
        NSURLSessionMultipathServiceType,
        NSURLSessionResponseDisposition,
        NSURLSessionTaskState,
        NSURLSessionWebSocketCloseCode,
        NSURLSessionWebSocketMessageType;

objc.NSURL _uriToNSURL(Uri uri) =>
    objc.NSURL.URLWithString(uri.toString().toNSString())!;
Uri _nsurlToUri(objc.NSURL url) =>
    Uri.parse(url.absoluteString!.toDartString());

abstract class _ObjectHolder<T extends objc.NSObject> {
  final T _nsObject;

  _ObjectHolder(this._nsObject);

  @override
  bool operator ==(Object other) {
    if (other is _ObjectHolder) {
      return _nsObject == other._nsObject;
    }
    return false;
  }

  @override
  int get hashCode => _nsObject.hashCode;
}

/// A cache for [URLRequest]s. Used by [URLSessionConfiguration.cache].
///
/// See [NSURLCache](https://developer.apple.com/documentation/foundation/nsurlcache)
class URLCache extends _ObjectHolder<ncb.NSURLCache> {
  URLCache._(super.c);

  /// The default URLCache.
  ///
  /// See [NSURLCache.sharedURLCache](https://developer.apple.com/documentation/foundation/nsurlcache/1413377-sharedurlcache)
  static URLCache? get sharedURLCache {
    final sharedCache = ncb.NSURLCache.getSharedURLCache();
    return URLCache._(sharedCache);
  }

  /// Create a new [URLCache] with the given memory and disk cache sizes.
  ///
  /// [memoryCapacity] and [diskCapacity] are specified in bytes.
  ///
  /// [directory] is the file system location where the disk cache will be
  /// stored. If `null` then the default directory will be used.
  ///
  /// See [NSURLCache initWithMemoryCapacity:diskCapacity:directoryURL:](https://developer.apple.com/documentation/foundation/nsurlcache/3240612-initwithmemorycapacity)
  factory URLCache.withCapacity({
    int memoryCapacity = 0,
    int diskCapacity = 0,
    Uri? directory,
  }) => URLCache._(
    ncb.NSURLCache.alloc().initWithMemoryCapacity(
      memoryCapacity,
      diskCapacity: diskCapacity,
      directoryURL: directory == null ? null : _uriToNSURL(directory),
    ),
  );
}

/// Controls the behavior of a URLSession.
///
/// See [NSURLSessionConfiguration](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration)
class URLSessionConfiguration
    extends _ObjectHolder<ncb.NSURLSessionConfiguration> {
  // A configuration created with
  // [`backgroundSessionConfigurationWithIdentifier`](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1407496-backgroundsessionconfigurationwi)
  final bool _isBackground;

  URLSessionConfiguration._(super.c, {required bool isBackground})
    : _isBackground = isBackground;

  /// A configuration suitable for performing HTTP uploads and downloads in
  /// the background.
  ///
  /// See [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1407496-backgroundsessionconfigurationwi)
  factory URLSessionConfiguration.backgroundSession(
    String identifier,
  ) => URLSessionConfiguration._(
    ncb.NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(
      identifier.toNSString(),
    ),
    isBackground: true,
  );

  /// A configuration that uses caching and saves cookies and credentials.
  ///
  /// See [NSURLSessionConfiguration defaultSessionConfiguration](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1411560-defaultsessionconfiguration)
  factory URLSessionConfiguration.defaultSessionConfiguration() =>
      URLSessionConfiguration._(
        ncb.NSURLSessionConfiguration.as(
          ncb.NSURLSessionConfiguration.getDefaultSessionConfiguration(),
        ),
        isBackground: false,
      );

  /// A session configuration that uses no persistent storage for caches,
  /// cookies, or credentials.
  ///
  /// See [NSURLSessionConfiguration ephemeralSessionConfiguration](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1410529-ephemeralsessionconfiguration)
  factory URLSessionConfiguration.ephemeralSessionConfiguration() =>
      URLSessionConfiguration._(
        ncb.NSURLSessionConfiguration.as(
          ncb.NSURLSessionConfiguration.getEphemeralSessionConfiguration(),
        ),
        isBackground: false,
      );

  /// Whether connections over a cellular network are allowed.
  ///
  /// See [NSURLSessionConfiguration.allowsCellularAccess](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1409406-allowscellularaccess)
  bool get allowsCellularAccess => _nsObject.allowsCellularAccess;
  set allowsCellularAccess(bool value) =>
      _nsObject.allowsCellularAccess = value;

  /// Whether connections are allowed when the user has selected Low Data Mode.
  ///
  /// See [NSURLSessionConfiguration.allowsConstrainedNetworkAccess](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/3235751-allowsconstrainednetworkaccess)
  bool get allowsConstrainedNetworkAccess =>
      _nsObject.allowsConstrainedNetworkAccess;
  set allowsConstrainedNetworkAccess(bool value) =>
      _nsObject.allowsConstrainedNetworkAccess = value;

  /// Whether connections are allowed over expensive networks.
  ///
  /// See [NSURLSessionConfiguration.allowsExpensiveNetworkAccess](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/3235752-allowsexpensivenetworkaccess)
  bool get allowsExpensiveNetworkAccess =>
      _nsObject.allowsExpensiveNetworkAccess;
  set allowsExpensiveNetworkAccess(bool value) =>
      _nsObject.allowsExpensiveNetworkAccess = value;

  /// The [URLCache] used to cache the results of [URLSessionTask]s.
  ///
  /// A value of `nil` indicates that no cache will be used.
  ///
  /// See [NSURLSessionConfiguration.URLCache](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1410148-urlcache)
  URLCache? get cache =>
      _nsObject.URLCache == null ? null : URLCache._(_nsObject.URLCache!);
  set cache(URLCache? cache) => _nsObject.URLCache = cache?._nsObject;

  /// Whether background tasks can be delayed by the system.
  ///
  /// See [NSURLSessionConfiguration.discretionary](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1411552-discretionary)
  bool get discretionary => _nsObject.isDiscretionary;
  set discretionary(bool value) => _nsObject.isDiscretionary = value;

  /// Additional headers to send with each request.
  ///
  /// Note that the getter for this field returns a **copy** of the headers.
  ///
  /// See [NSURLSessionConfiguration.HTTPAdditionalHeaders](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1411532-httpadditionalheaders)
  Map<String, String>? get httpAdditionalHeaders {
    if (_nsObject.HTTPAdditionalHeaders case var additionalHeaders?) {
      final headers = objc.NSDictionary.as(additionalHeaders);
      return (objc.toDartObject(headers) as Map).cast<String, String>();
    }
    return null;
  }

  set httpAdditionalHeaders(Map<String, String>? headers) {
    if (headers == null) {
      _nsObject.HTTPAdditionalHeaders = null;
      return;
    }
    _nsObject.HTTPAdditionalHeaders =
        objc.toObjCObject(headers) as objc.NSMutableDictionary;
  }

  /// What policy to use when deciding whether to accept cookies.
  ///
  /// See [NSURLSessionConfiguration.HTTPCookieAcceptPolicy](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1408933-httpcookieacceptpolicy).
  NSHTTPCookieAcceptPolicy get httpCookieAcceptPolicy =>
      _nsObject.HTTPCookieAcceptPolicy;
  set httpCookieAcceptPolicy(NSHTTPCookieAcceptPolicy value) =>
      _nsObject.HTTPCookieAcceptPolicy = value;

  /// The maximum number of connections that a URLSession can have open to the
  /// same host.
  //
  /// See [NSURLSessionConfiguration.HTTPMaximumConnectionsPerHost](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1407597-httpmaximumconnectionsperhost).
  int get httpMaximumConnectionsPerHost =>
      _nsObject.HTTPMaximumConnectionsPerHost;
  set httpMaximumConnectionsPerHost(int value) =>
      _nsObject.HTTPMaximumConnectionsPerHost = value;

  /// Whether requests should include cookies from the cookie store.
  ///
  /// See [NSURLSessionConfiguration.HTTPShouldSetCookies](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1411589-httpshouldsetcookies)
  bool get httpShouldSetCookies => _nsObject.HTTPShouldSetCookies;
  set httpShouldSetCookies(bool value) =>
      _nsObject.HTTPShouldSetCookies = value;

  /// Whether to use [HTTP pipelining](https://en.wikipedia.org/wiki/HTTP_pipelining).
  ///
  /// See [NSURLSessionConfiguration.HTTPShouldUsePipelining](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1411657-httpshouldusepipelining)
  bool get httpShouldUsePipelining => _nsObject.HTTPShouldUsePipelining;
  set httpShouldUsePipelining(bool value) =>
      _nsObject.HTTPShouldUsePipelining = value;

  /// What type of Multipath TCP connections to use.
  ///
  /// See [NSURLSessionConfiguration.multipathServiceType](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/2875967-multipathservicetype)
  NSURLSessionMultipathServiceType get multipathServiceType =>
      _nsObject.multipathServiceType;
  set multipathServiceType(NSURLSessionMultipathServiceType value) =>
      _nsObject.multipathServiceType = value;

  /// Provides in indication to the operating system on what type of requests
  /// are being sent.
  ///
  /// See [NSURLSessionConfiguration.networkServiceType](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1411606-networkservicetype).
  NSURLRequestNetworkServiceType get networkServiceType =>
      _nsObject.networkServiceType;
  set networkServiceType(NSURLRequestNetworkServiceType value) =>
      _nsObject.networkServiceType = value;

  /// Controls how to deal with response caching.
  ///
  /// See [NSURLSessionConfiguration.requestCachePolicy](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1411655-requestcachepolicy)
  NSURLRequestCachePolicy get requestCachePolicy =>
      _nsObject.requestCachePolicy;
  set requestCachePolicy(NSURLRequestCachePolicy value) =>
      _nsObject.requestCachePolicy = value;

  /// Whether the app should be resumed when background tasks complete.
  ///
  /// See [NSURLSessionConfiguration.sessionSendsLaunchEvents](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1617174-sessionsendslaunchevents)
  bool get sessionSendsLaunchEvents => _nsObject.sessionSendsLaunchEvents;
  set sessionSendsLaunchEvents(bool value) =>
      _nsObject.sessionSendsLaunchEvents = value;

  /// The timeout interval if data is not received.
  ///
  /// See [NSURLSessionConfiguration.timeoutIntervalForRequest](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1408259-timeoutintervalforrequest)
  Duration get timeoutIntervalForRequest => Duration(
    microseconds:
        (_nsObject.timeoutIntervalForRequest * Duration.microsecondsPerSecond)
            .round(),
  );

  set timeoutIntervalForRequest(Duration interval) {
    _nsObject.timeoutIntervalForRequest =
        interval.inMicroseconds.toDouble() / Duration.microsecondsPerSecond;
  }

  /// Whether tasks should wait for connectivity or fail immediately.
  ///
  /// See [NSURLSessionConfiguration.waitsForConnectivity](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/2908812-waitsforconnectivity)
  bool get waitsForConnectivity => _nsObject.waitsForConnectivity;
  set waitsForConnectivity(bool value) =>
      _nsObject.waitsForConnectivity = value;

  @override
  String toString() =>
      '[URLSessionConfiguration '
      'allowsCellularAccess=$allowsCellularAccess '
      'allowsConstrainedNetworkAccess=$allowsConstrainedNetworkAccess '
      'allowsExpensiveNetworkAccess=$allowsExpensiveNetworkAccess '
      'discretionary=$discretionary '
      'httpAdditionalHeaders=$httpAdditionalHeaders '
      'httpCookieAcceptPolicy=$httpCookieAcceptPolicy '
      'httpShouldSetCookies=$httpShouldSetCookies '
      'httpMaximumConnectionsPerHost=$httpMaximumConnectionsPerHost '
      'httpShouldUsePipelining=$httpShouldUsePipelining '
      'requestCachePolicy=$requestCachePolicy '
      'sessionSendsLaunchEvents=$sessionSendsLaunchEvents '
      'shouldUseExtendedBackgroundIdleMode='
      'timeoutIntervalForRequest=$timeoutIntervalForRequest '
      'waitsForConnectivity=$waitsForConnectivity'
      ']';
}

/// The response associated with loading an URL.
///
/// See [NSURLResponse](https://developer.apple.com/documentation/foundation/nsurlresponse)
class URLResponse extends _ObjectHolder<ncb.NSURLResponse> {
  URLResponse._(super.c);

  factory URLResponse._exactURLResponseType(ncb.NSURLResponse response) {
    if (ncb.NSHTTPURLResponse.isA(response)) {
      return HTTPURLResponse._(ncb.NSHTTPURLResponse.as(response));
    }
    return URLResponse._(response);
  }

  /// The expected amount of data returned with the response.
  ///
  /// See [NSURLResponse.expectedContentLength](https://developer.apple.com/documentation/foundation/nsurlresponse/1413507-expectedcontentlength)
  int get expectedContentLength => _nsObject.expectedContentLength;

  /// The MIME type of the response.
  ///
  /// See [NSURLResponse.MIMEType](https://developer.apple.com/documentation/foundation/nsurlresponse/1411613-mimetype)
  String? get mimeType => _nsObject.MIMEType?.toDartString();

  @override
  String toString() =>
      '[URLResponse '
      'mimeType=$mimeType '
      'expectedContentLength=$expectedContentLength'
      ']';
}

/// The response associated with loading a HTTP URL.
///
/// See [NSHTTPURLResponse](https://developer.apple.com/documentation/foundation/nshttpurlresponse)
class HTTPURLResponse extends URLResponse {
  final ncb.NSHTTPURLResponse _httpUrlResponse;

  HTTPURLResponse._(ncb.NSHTTPURLResponse super.c)
    : _httpUrlResponse = c,
      super._();

  /// The HTTP status code of the response (e.g. 200).
  ///
  /// See [HTTPURLResponse.statusCode](https://developer.apple.com/documentation/foundation/nshttpurlresponse/1409395-statuscode)
  int get statusCode => _httpUrlResponse.statusCode;

  /// The HTTP headers of the response.
  ///
  /// See [HTTPURLResponse.allHeaderFields](https://developer.apple.com/documentation/foundation/nshttpurlresponse/1417930-allheaderfields)
  Map<String, String> get allHeaderFields =>
      (objc.toDartObject(_httpUrlResponse.allHeaderFields) as Map)
          .cast<String, String>();

  @override
  String toString() =>
      '[HTTPURLResponse '
      'statusCode=$statusCode '
      'mimeType=$mimeType '
      'expectedContentLength=$expectedContentLength'
      ']';
}

/// A WebSocket message.
///
/// See [NSURLSessionWebSocketMessage](https://developer.apple.com/documentation/foundation/nsurlsessionwebsocketmessage)
class URLSessionWebSocketMessage
    extends _ObjectHolder<ncb.NSURLSessionWebSocketMessage> {
  URLSessionWebSocketMessage._(super.nsObject);

  /// Create a WebSocket data message.
  ///
  /// See [NSURLSessionWebSocketMessage initWithData:](https://developer.apple.com/documentation/foundation/nsurlsessionwebsocketmessage/3181192-initwithdata)
  factory URLSessionWebSocketMessage.fromData(objc.NSData d) =>
      URLSessionWebSocketMessage._(
        ncb.NSURLSessionWebSocketMessage.alloc().initWithData(d),
      );

  /// Create a WebSocket string message.
  ///
  /// See [NSURLSessionWebSocketMessage initWitString:](https://developer.apple.com/documentation/foundation/nsurlsessionwebsocketmessage/3181193-initwithstring)
  factory URLSessionWebSocketMessage.fromString(String s) =>
      URLSessionWebSocketMessage._(
        ncb.NSURLSessionWebSocketMessage.alloc().initWithString(s.toNSString()),
      );

  /// The data associated with the WebSocket message.
  ///
  /// Will be `null` if the [URLSessionWebSocketMessage] is a string message.
  ///
  /// See [NSURLSessionWebSocketMessage.data](https://developer.apple.com/documentation/foundation/nsurlsessionwebsocketmessage/3181191-data)
  objc.NSData? get data => _nsObject.data;

  /// The string associated with the WebSocket message.
  ///
  /// Will be `null` if the [URLSessionWebSocketMessage] is a data message.
  ///
  /// See [NSURLSessionWebSocketMessage.string](https://developer.apple.com/documentation/foundation/nsurlsessionwebsocketmessage/3181194-string)
  String? get string => _nsObject.string?.toDartString();

  /// The type of the WebSocket message.
  ///
  /// See [NSURLSessionWebSocketMessage.type](https://developer.apple.com/documentation/foundation/nsurlsessionwebsocketmessage/3181195-type)
  NSURLSessionWebSocketMessageType get type => _nsObject.type;

  @override
  String toString() =>
      '[URLSessionWebSocketMessage type=$type string=$string data=$data]';
}

/// A task associated with downloading a URI.
///
/// See [NSURLSessionTask](https://developer.apple.com/documentation/foundation/nsurlsessiontask)
class URLSessionTask extends _ObjectHolder<ncb.NSURLSessionTask> {
  URLSessionTask._(super.c);

  /// Cancels the task.
  ///
  /// See [NSURLSessionTask cancel](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1411591-cancel)
  void cancel() {
    _nsObject.cancel();
  }

  /// Resumes a suspended task (new tasks start as suspended).
  ///
  /// See [NSURLSessionTask resume](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1411121-resume)
  void resume() {
    _nsObject.resume();
  }

  /// Suspends a task (prevents it from transferring data).
  ///
  /// See [NSURLSessionTask suspend](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1411565-suspend)
  void suspend() {
    _nsObject.suspend();
  }

  /// The current state of the task.
  ///
  /// See [NSURLSessionTask.state](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1409888-state)
  NSURLSessionTaskState get state => _nsObject.state;

  /// The relative priority [0, 1] that the host should use to handle the
  /// request.
  ///
  /// See [NSURLSessionTask.priority](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1410569-priority)
  double get priority => _nsObject.priority;

  /// The relative priority [0, 1] that the host should use to handle the
  /// request.
  ///
  /// See [NSURLSessionTask.priority](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1410569-priority)
  set priority(double value) => _nsObject.priority = value;

  /// The request currently being handled by the task.
  ///
  /// May be different from [originalRequest] if the server responds with a
  /// redirect.
  ///
  /// See [NSURLSessionTask.currentRequest](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1411649-currentrequest)
  URLRequest? get currentRequest {
    final request = _nsObject.currentRequest;
    if (request == null) {
      return null;
    } else {
      return URLRequest._(request);
    }
  }

  /// The original request associated with the task.
  ///
  /// May be different from [currentRequest] if the server responds with a
  /// redirect.
  ///
  /// See [NSURLSessionTask.originalRequest](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1411572-originalrequest)
  URLRequest? get originalRequest {
    final request = _nsObject.originalRequest;
    if (request == null) {
      return null;
    } else {
      return URLRequest._(request);
    }
  }

  /// The server response to the request associated with this task.
  ///
  /// See [NSURLSessionTask.response](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1410586-response)
  URLResponse? get response {
    final nsResponse = _nsObject.response;
    if (nsResponse == null) {
      return null;
    }
    return URLResponse._exactURLResponseType(nsResponse);
  }

  /// An error indicating why the task failed or `null` on success.
  ///
  /// See [NSURLSessionTask.error](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1408145-error)
  objc.NSError? get error => _nsObject.error;

  /// The user-assigned description for the task.
  ///
  /// See [NSURLSessionTask.taskDescription](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1409798-taskdescription)
  String get taskDescription => _nsObject.taskDescription?.toDartString() ?? '';

  /// The user-assigned description for the task.
  ///
  /// See [NSURLSessionTask.taskDescription](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1409798-taskdescription)
  set taskDescription(String value) =>
      _nsObject.taskDescription = value.toNSString();

  /// A unique ID for the [URLSessionTask] in a [URLSession].
  ///
  /// See [NSURLSessionTask.taskIdentifier](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1411231-taskidentifier)
  int get taskIdentifier => _nsObject.taskIdentifier;

  /// The number of content bytes that are expected to be received from the
  /// server.
  ///
  /// See [NSURLSessionTask.countOfBytesReceived](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1410663-countofbytesexpectedtoreceive)
  int get countOfBytesExpectedToReceive =>
      _nsObject.countOfBytesExpectedToReceive;

  /// The number of content bytes that have been received from the server.
  ///
  /// See [NSURLSessionTask.countOfBytesReceived](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1411581-countofbytesreceived)
  int get countOfBytesReceived => _nsObject.countOfBytesReceived;

  /// The number of content bytes that the task expects to send to the server.
  ///
  /// See [NSURLSessionTask.countOfBytesExpectedToSend](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1411534-countofbytesexpectedtosend)
  int get countOfBytesExpectedToSend => _nsObject.countOfBytesExpectedToSend;

  /// Whether the body of the response should be delivered incrementally or not.
  ///
  /// [NSURLSessionTask.countOfBytesSent](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1410444-countofbytessent)
  int get countOfBytesSent => _nsObject.countOfBytesSent;

  /// Whether the body of the response should be delivered incrementally or not.
  ///
  /// See [NSURLSessionTask.prefersIncrementalDelivery](https://developer.apple.com/documentation/foundation/nsurlsessiontask/3735881-prefersincrementaldelivery)
  bool get prefersIncrementalDelivery => _nsObject.prefersIncrementalDelivery;

  /// Whether the body of the response should be delivered incrementally or not.
  ///
  /// See [NSURLSessionTask.prefersIncrementalDelivery](https://developer.apple.com/documentation/foundation/nsurlsessiontask/3735881-prefersincrementaldelivery)
  set prefersIncrementalDelivery(bool value) =>
      _nsObject.prefersIncrementalDelivery = value;

  String _toStringHelper(String className) =>
      '[$className '
      'taskDescription=$taskDescription '
      'taskIdentifier=$taskIdentifier '
      'countOfBytesExpectedToReceive=$countOfBytesExpectedToReceive '
      'countOfBytesReceived=$countOfBytesReceived '
      'countOfBytesExpectedToSend=$countOfBytesExpectedToSend '
      'countOfBytesSent=$countOfBytesSent '
      'priority=$priority '
      'state=$state '
      'prefersIncrementalDelivery=$prefersIncrementalDelivery'
      ']';

  @override
  String toString() => _toStringHelper('URLSessionTask');
}

/// A task associated with downloading a URI to a file.
///
/// See [NSURLSessionDownloadTask](https://developer.apple.com/documentation/foundation/nsurlsessiondownloadtask)
class URLSessionDownloadTask extends URLSessionTask {
  URLSessionDownloadTask._(ncb.NSURLSessionDownloadTask super.c) : super._();

  @override
  String toString() => _toStringHelper('URLSessionDownloadTask');
}

/// A task associated with a WebSocket connection.
///
/// See [NSURLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/nsurlsessionwebsockettask)
class URLSessionWebSocketTask extends URLSessionTask {
  final ncb.NSURLSessionWebSocketTask _urlSessionWebSocketTask;

  URLSessionWebSocketTask._(ncb.NSURLSessionWebSocketTask super.c)
    : _urlSessionWebSocketTask = c,
      super._();

  /// The close code set when the WebSocket connection is closed.
  ///
  /// See [NSURLSessionWebSocketTask.closeCode](https://developer.apple.com/documentation/foundation/nsurlsessionwebsockettask/3181201-closecode)
  int get closeCode => _urlSessionWebSocketTask.closeCode;

  /// The close reason set when the WebSocket connection is closed.
  /// If there is no close reason available this property will be null.
  ///
  /// See [NSURLSessionWebSocketTask.closeReason](https://developer.apple.com/documentation/foundation/nsurlsessionwebsockettask/3181202-closereason)
  objc.NSData? get closeReason => _urlSessionWebSocketTask.closeReason;

  /// Sends a single WebSocket message.
  ///
  /// The returned future will complete successfully when the message is sent
  /// and with an [Error] on failure.
  ///
  /// See [NSURLSessionWebSocketTask.sendMessage:completionHandler:](https://developer.apple.com/documentation/foundation/nsurlsessionwebsockettask/3181205-sendmessage)
  Future<void> sendMessage(URLSessionWebSocketMessage message) async {
    final completer = Completer<void>();
    _urlSessionWebSocketTask.sendMessage(
      message._nsObject,
      completionHandler: ncb.ObjCBlock_ffiVoid_NSError.listener((error) {
        if (error == null) {
          completer.complete();
        } else {
          completer.completeError(error);
        }
      }),
    );

    await completer.future;
  }

  /// Receives a single WebSocket message.
  ///
  /// Throws an [Error] on failure.
  ///
  /// See [NSURLSessionWebSocketTask.receiveMessageWithCompletionHandler:](https://developer.apple.com/documentation/foundation/nsurlsessionwebsockettask/3181204-receivemessagewithcompletionhand)
  Future<URLSessionWebSocketMessage> receiveMessage() async {
    final completer = Completer<URLSessionWebSocketMessage>();
    _urlSessionWebSocketTask.receiveMessageWithCompletionHandler(
      ncb.ObjCBlock_ffiVoid_NSURLSessionWebSocketMessage_NSError.listener((
        message,
        error,
      ) {
        if (error != null) {
          completer.completeError(error);
        } else if (message != null) {
          completer.complete(URLSessionWebSocketMessage._(message));
        } else {
          completer.completeError(
            StateError('one of message or error must be non-null'),
          );
        }
      }),
    );
    return completer.future;
  }

  /// Sends close frame with the given code and optional reason.
  ///
  /// See [NSURLSessionWebSocketTask.cancelWithCloseCode:reason:](https://developer.apple.com/documentation/foundation/nsurlsessionwebsockettask/3181200-cancelwithclosecode)
  void cancelWithCloseCode(int closeCode, objc.NSData? reason) {
    _urlSessionWebSocketTask.cancelWithCloseCode(closeCode, reason: reason);
  }

  @override
  String toString() => _toStringHelper('NSURLSessionWebSocketTask');
}

/// A request to load a URL.
///
/// See [NSURLRequest](https://developer.apple.com/documentation/foundation/nsurlrequest)
class URLRequest extends _ObjectHolder<ncb.NSURLRequest> {
  URLRequest._(super.c);

  /// Creates a request for a URL.
  ///
  /// See [NSURLRequest.requestWithURL:](https://developer.apple.com/documentation/foundation/nsurlrequest/1528603-requestwithurl)
  factory URLRequest.fromUrl(Uri uri) =>
      URLRequest._(ncb.NSURLRequest.requestWithURL(_uriToNSURL(uri)));

  /// Returns all of the HTTP headers for the request.
  ///
  /// See [NSURLRequest.allHTTPHeaderFields](https://developer.apple.com/documentation/foundation/nsurlrequest/1418477-allhttpheaderfields)
  Map<String, String>? get allHttpHeaderFields {
    if (_nsObject.allHTTPHeaderFields == null) {
      return null;
    } else {
      return (objc.toDartObject(_nsObject.allHTTPHeaderFields!) as Map)
          .cast<String, String>();
    }
  }

  /// Controls how to deal with caching for the request.
  ///
  /// See [NSURLSession.cachePolicy](https://developer.apple.com/documentation/foundation/nsurlrequest/1407944-cachepolicy)
  NSURLRequestCachePolicy get cachePolicy => _nsObject.cachePolicy;

  /// The body of the request.
  ///
  /// See [NSURLRequest.HTTPBody](https://developer.apple.com/documentation/foundation/nsurlrequest/1411317-httpbody)
  objc.NSData? get httpBody => _nsObject.HTTPBody;

  /// The HTTP request method (e.g. 'GET').
  ///
  /// See [NSURLRequest.HTTPMethod](https://developer.apple.com/documentation/foundation/nsurlrequest/1413030-httpmethod)
  ///
  /// NOTE: The documentation for `NSURLRequest.HTTPMethod` says that the
  /// property is nullable but, in practice, assigning it to null will produce
  /// an error.
  String get httpMethod => _nsObject.HTTPMethod!.toDartString();

  /// The timeout interval during the connection attempt.
  ///
  /// See [NSURLSession.timeoutInterval](https://developer.apple.com/documentation/foundation/nsurlrequest/1418229-timeoutinterval)
  Duration get timeoutInterval => Duration(
    microseconds: (_nsObject.timeoutInterval * Duration.microsecondsPerSecond)
        .round(),
  );

  /// The requested URL.
  ///
  /// See [URLRequest.URL](https://developer.apple.com/documentation/foundation/nsurlrequest/1408996-url)
  Uri? get url {
    final nsUrl = _nsObject.URL;
    if (nsUrl == null) {
      return null;
    }
    return _nsurlToUri(nsUrl);
  }

  @override
  String toString() =>
      '[URLRequest '
      'allHttpHeaderFields=$allHttpHeaderFields '
      'cachePolicy=$cachePolicy '
      'httpBody=$httpBody '
      'httpMethod=$httpMethod '
      'timeoutInterval=$timeoutInterval '
      'url=$url '
      ']';
}

/// A mutable request to load a URL.
///
/// See [NSMutableURLRequest](https://developer.apple.com/documentation/foundation/nsmutableurlrequest)
class MutableURLRequest extends URLRequest {
  final ncb.NSMutableURLRequest _mutableUrlRequest;

  MutableURLRequest._(ncb.NSMutableURLRequest super.c)
    : _mutableUrlRequest = c,
      super._();

  /// Creates a request for a URL.
  ///
  /// See [NSMutableURLRequest.requestWithURL:](https://developer.apple.com/documentation/foundation/nsmutableurlrequest/1414617-allhttpheaderfields)
  factory MutableURLRequest.fromUrl(Uri uri) {
    final url = objc.NSURL.URLWithString(uri.toString().toNSString())!;
    return MutableURLRequest._(ncb.NSMutableURLRequest.requestWithURL(url));
  }

  set cachePolicy(NSURLRequestCachePolicy value) =>
      _mutableUrlRequest.cachePolicy$1 = value;

  set httpBody(objc.NSData? data) {
    _mutableUrlRequest.HTTPBody = data;
  }

  /// Sets the body of the request to the given [Stream].
  ///
  /// See [NSMutableURLRequest.HTTPBodyStream](https://developer.apple.com/documentation/foundation/nsurlrequest/1407341-httpbodystream).
  set httpBodyStream(objc.NSInputStream stream) {
    _mutableUrlRequest.HTTPBodyStream = stream;
  }

  set httpMethod(String method) {
    _mutableUrlRequest.HTTPMethod = method.toNSString();
  }

  set timeoutInterval(Duration interval) {
    _mutableUrlRequest.timeoutInterval$1 =
        interval.inMicroseconds.toDouble() / Duration.microsecondsPerSecond;
  }

  /// Set the value of a header field.
  ///
  /// See [NSMutableURLRequest setValue:forHTTPHeaderField:](https://developer.apple.com/documentation/foundation/nsmutableurlrequest/1408793-setvalue)
  void setValueForHttpHeaderField(String value, String field) {
    _mutableUrlRequest.setValue(
      field.toNSString(),
      forHTTPHeaderField: value.toNSString(),
    );
  }

  @override
  String toString() =>
      '[MutableURLRequest '
      'allHttpHeaderFields=$allHttpHeaderFields '
      'cachePolicy=$cachePolicy '
      'httpBody=$httpBody '
      'httpMethod=$httpMethod '
      'timeoutInterval=$timeoutInterval '
      'url=$url '
      ']';
}

/// A client that can make network requests to a server.
///
/// See [NSURLSession](https://developer.apple.com/documentation/foundation/nsurlsession)
class URLSession extends _ObjectHolder<ncb.NSURLSession> {
  // Provide our own native delegate to `NSURLSession` because delegates can be
  // called on arbitrary threads and Dart code cannot be.
  // Indicates if the session is a background session. Copied from the
  // [URLSessionConfiguration._isBackground] associated with this [URLSession].
  final bool _isBackground;

  static ncb.NSURLSessionDelegate delegate(
    bool isBackground, {
    URLRequest? Function(
      URLSession session,
      URLSessionTask task,
      HTTPURLResponse response,
      URLRequest newRequest,
    )?
    onRedirect,
    NSURLSessionResponseDisposition Function(
      URLSession session,
      URLSessionTask task,
      URLResponse response,
    )?
    onResponse,
    void Function(URLSession session, URLSessionTask task, objc.NSData error)?
    onData,
    void Function(URLSession session, URLSessionDownloadTask task, Uri uri)?
    onFinishedDownloading,
    void Function(URLSession session, URLSessionTask task, objc.NSError? error)?
    onComplete,
    void Function(
      URLSession session,
      URLSessionWebSocketTask task,
      String? protocol,
    )?
    onWebSocketTaskOpened,
    void Function(
      URLSession session,
      URLSessionWebSocketTask task,
      int closeCode,
      objc.NSData? reason,
    )?
    onWebSocketTaskClosed,
  }) {
    final protoBuilder = objc.ObjCProtocolBuilder();

    if (onComplete != null) {
      ncb.NSURLSessionDataDelegate$Builder.URLSession_task_didCompleteWithError_
          .implementAsListener(protoBuilder, (nsSession, nsTask, nsError) {
            onComplete(
              URLSession._(nsSession, isBackground: isBackground),
              URLSessionTask._(nsTask),
              nsError,
            );
          });
    }

    if (onRedirect != null) {
      ncb
          .NSURLSessionDataDelegate$Builder
          // ignore: lines_longer_than_80_chars
          .URLSession_task_willPerformHTTPRedirection_newRequest_completionHandler_
          .implementAsListener(
            protoBuilder,

            // ignore: lines_longer_than_80_chars
            (nsSession, nsTask, nsResponse, nsRequest, nsRequestCompleter) {
              final request = URLRequest._(nsRequest);
              final response =
                  URLResponse._exactURLResponseType(nsResponse)
                      as HTTPURLResponse;
              final redirectRequest = onRedirect(
                URLSession._(nsSession, isBackground: isBackground),
                URLSessionTask._(nsTask),
                response,
                request,
              );
              nsRequestCompleter.call(redirectRequest?._nsObject);
            },
          );
    }

    if (onResponse != null) {
      ncb
          .NSURLSessionDataDelegate$Builder
          .URLSession_dataTask_didReceiveResponse_completionHandler_
          .implementAsListener(protoBuilder, (
            nsSession,
            nsDataTask,
            nsResponse,
            nsCompletionHandler,
          ) {
            final exactResponse = URLResponse._exactURLResponseType(nsResponse);
            final disposition = onResponse(
              URLSession._(nsSession, isBackground: isBackground),
              URLSessionTask._(nsDataTask),
              exactResponse,
            );
            nsCompletionHandler.call(disposition);
          });
    }

    if (onData != null) {
      ncb.NSURLSessionDataDelegate$Builder.URLSession_dataTask_didReceiveData_
          .implementAsListener(protoBuilder, (nsSession, nsDataTask, nsData) {
            onData(
              URLSession._(nsSession, isBackground: isBackground),
              URLSessionTask._(nsDataTask),
              nsData,
            );
          });
    }

    if (onFinishedDownloading != null) {
      ncb
          .NSURLSessionDownloadDelegate$Builder
          .URLSession_downloadTask_didFinishDownloadingToURL_
          .implementAsBlocking(protoBuilder, (nsSession, nsTask, nsUrl) {
            onFinishedDownloading(
              URLSession._(nsSession, isBackground: isBackground),
              URLSessionDownloadTask._(nsTask),
              _nsurlToUri(nsUrl),
            );
          });
    }

    if (onWebSocketTaskOpened != null) {
      ncb
          .NSURLSessionWebSocketDelegate$Builder
          .URLSession_webSocketTask_didOpenWithProtocol_
          .implementAsListener(protoBuilder, (nsSession, nsTask, nsProtocol) {
            onWebSocketTaskOpened(
              URLSession._(nsSession, isBackground: isBackground),
              URLSessionWebSocketTask._(nsTask),
              nsProtocol?.toDartString(),
            );
          });
    }

    if (onWebSocketTaskClosed != null) {
      ncb
          .NSURLSessionWebSocketDelegate$Builder
          .URLSession_webSocketTask_didCloseWithCode_reason_
          .implementAsListener(protoBuilder, (
            nsSession,
            nsTask,
            closeCode,
            reason,
          ) {
            onWebSocketTaskClosed(
              URLSession._(nsSession, isBackground: isBackground),
              URLSessionWebSocketTask._(nsTask),
              closeCode,
              reason,
            );
          });
    }

    return ncb.NSURLSessionDelegate.as(protoBuilder.build());
  }

  URLSession._(super.c, {required bool isBackground})
    : _isBackground = isBackground;

  /// A client with reasonable default behavior.
  ///
  /// See [NSURLSession.sharedSession](https://developer.apple.com/documentation/foundation/nsurlsession/1409000-sharedsession)
  factory URLSession.sharedSession() =>
      URLSession._(ncb.NSURLSession.getSharedSession(), isBackground: false);

  /// A client with a given configuration.
  ///
  /// If [onRedirect] is set then it will be called whenever a HTTP
  /// request returns a redirect response (e.g. 302). The `response` parameter
  /// contains the response from the server. The `newRequest` parameter contains
  /// a follow-up request that would honor the server's redirect. If the return
  /// value of this function is `null` then the redirect will not occur.
  /// Otherwise, the returned [URLRequest] (usually `newRequest`) will be
  /// executed. [onRedirect] should not throw. [onRedirect] will not be called
  /// for background sessions, which automatically follow redirects. See
  /// [URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:](https://developer.apple.com/documentation/foundation/nsurlsessiontaskdelegate/1411626-urlsession)
  ///
  /// If [onResponse] is set then it will be called whenever a valid response
  /// is received. The returned [NSURLSessionResponseDisposition] will decide
  /// how the content of the response is processed. [onResponse] should not
  /// throw. See
  /// [URLSession:dataTask:didReceiveResponse:completionHandler:](https://developer.apple.com/documentation/foundation/nsurlsessiondatadelegate/1410027-urlsession).
  ///
  /// If [onData] is set then it will be called whenever response data is
  /// received. If the amount of received data is large, then it may be
  /// called more than once. See
  /// [URLSession:dataTask:didReceiveData:](https://developer.apple.com/documentation/foundation/nsurlsessiondatadelegate/1411528-urlsession)
  ///
  /// If [onFinishedDownloading] is set then it will be called whenever a
  /// [URLSessionDownloadTask] has finished downloading.
  ///
  /// If [onComplete] is set then it will be called when a task completes. If
  /// `error` is `null` then the request completed successfully. See
  /// [URLSession:task:didCompleteWithError:](https://developer.apple.com/documentation/foundation/nsurlsessiontaskdelegate/1411610-urlsession)
  ///
  /// See [sessionWithConfiguration:delegate:delegateQueue:](https://developer.apple.com/documentation/foundation/nsurlsession/1411597-sessionwithconfiguration)
  ///
  /// If [onWebSocketTaskOpened] is set then it will be called when a
  /// [URLSessionWebSocketTask] successfully negotiated the handshake with the
  /// server.
  ///
  /// If [onWebSocketTaskClosed] is set then it will be called if a
  /// [URLSessionWebSocketTask] receives a close control frame from the server.
  /// NOTE: A [URLSessionWebSocketTask.receiveMessage] must be in flight for
  /// [onWebSocketTaskClosed] to be called.
  factory URLSession.sessionWithConfiguration(
    URLSessionConfiguration config, {
    URLRequest? Function(
      URLSession session,
      URLSessionTask task,
      HTTPURLResponse response,
      URLRequest newRequest,
    )?
    onRedirect,
    NSURLSessionResponseDisposition Function(
      URLSession session,
      URLSessionTask task,
      URLResponse response,
    )?
    onResponse,
    void Function(URLSession session, URLSessionTask task, objc.NSData data)?
    onData,
    void Function(URLSession session, URLSessionDownloadTask task, Uri uri)?
    onFinishedDownloading,
    void Function(URLSession session, URLSessionTask task, objc.NSError? error)?
    onComplete,
    void Function(
      URLSession session,
      URLSessionWebSocketTask task,
      String? protocol,
    )?
    onWebSocketTaskOpened,
    void Function(
      URLSession session,
      URLSessionWebSocketTask task,
      int? closeCode,
      objc.NSData? reason,
    )?
    onWebSocketTaskClosed,
  }) {
    // Avoid the complexity of simultaneous or out-of-order delegate callbacks
    // by only allowing callbacks to execute sequentially.
    // See https://developer.apple.com/forums/thread/47252
    final queue = ncb.NSOperationQueue()
      ..maxConcurrentOperationCount = 1
      ..name = 'cupertino_http.NSURLSessionDelegateQueue'.toNSString();

    final hasDelegate =
        (onRedirect ??
            onResponse ??
            onData ??
            onFinishedDownloading ??
            onComplete ??
            onWebSocketTaskOpened ??
            onWebSocketTaskClosed) !=
        null;

    if (hasDelegate) {
      return URLSession._(
        ncb.NSURLSession.sessionWithConfiguration$1(
          config._nsObject,
          delegate: delegate(
            config._isBackground,
            onRedirect: onRedirect,
            onResponse: onResponse,
            onData: onData,
            onFinishedDownloading: onFinishedDownloading,
            onComplete: onComplete,
            onWebSocketTaskOpened: onWebSocketTaskOpened,
            onWebSocketTaskClosed: onWebSocketTaskClosed,
          ),
          delegateQueue: queue,
        ),
        isBackground: config._isBackground,
      );
    } else {
      return URLSession._(
        ncb.NSURLSession.sessionWithConfiguration(config._nsObject),
        isBackground: config._isBackground,
      );
    }
  }

  /// A **copy** of the configuration for this session.
  ///
  /// See [NSURLSession.configuration](https://developer.apple.com/documentation/foundation/nsurlsession/1411477-configuration)
  URLSessionConfiguration get configuration => URLSessionConfiguration._(
    ncb.NSURLSessionConfiguration.as(_nsObject.configuration),
    isBackground: _isBackground,
  );

  /// A description of the session that may be useful for debugging.
  ///
  /// See [NSURLSession.sessionDescription](https://developer.apple.com/documentation/foundation/nsurlsession/1408277-sessiondescription)
  String? get sessionDescription =>
      _nsObject.sessionDescription?.toDartString();
  set sessionDescription(String? value) =>
      _nsObject.sessionDescription = value?.toNSString();

  /// Create a [URLSessionTask] that accesses a server URL.
  ///
  /// See [NSURLSession dataTaskWithRequest:](https://developer.apple.com/documentation/foundation/nsurlsession/1410592-datataskwithrequest)
  URLSessionTask dataTaskWithRequest(URLRequest request) =>
      URLSessionTask._(_nsObject.dataTaskWithRequest(request._nsObject));

  /// Creates a [URLSessionTask] that accesses a server URL and calls
  /// [completion] when done.
  ///
  /// See [NSURLSession dataTaskWithRequest:completionHandler:](https://developer.apple.com/documentation/foundation/nsurlsession/1407613-datataskwithrequest)
  URLSessionTask dataTaskWithCompletionHandler(
    URLRequest request,
    void Function(objc.NSData? data, URLResponse? response, objc.NSError? error)
    completion,
  ) {
    if (_isBackground) {
      throw UnsupportedError(
        'dataTaskWithCompletionHandler is not supported in background '
        'sessions',
      );
    }
    final completer =
        ncb.ObjCBlock_ffiVoid_NSData_NSURLResponse_NSError.listener((
          data,
          response,
          error,
        ) {
          completion(
            data,
            response == null
                ? null
                : URLResponse._exactURLResponseType(response),
            error,
          );
        });

    final task = ncb.NSURLSessionAsynchronousConvenience(
      _nsObject,
    ).dataTaskWithRequest$1(request._nsObject, completionHandler: completer);

    return URLSessionTask._(task);
  }

  /// Creates a [URLSessionDownloadTask] that downloads the data from a server
  /// URL.
  ///
  /// Provide a `onFinishedDownloading` handler in the [URLSession] factory to
  /// receive notifications when the data has completed downloaded.
  ///
  /// See [NSURLSession downloadTaskWithRequest:](https://developer.apple.com/documentation/foundation/nsurlsession/1411481-downloadtaskwithrequest)
  URLSessionDownloadTask downloadTaskWithRequest(URLRequest request) =>
      URLSessionDownloadTask._(
        _nsObject.downloadTaskWithRequest(request._nsObject),
      );

  /// Creates a [URLSessionWebSocketTask] that represents a connection to a
  /// WebSocket endpoint.
  ///
  /// To add custom protocols, add a "Sec-WebSocket-Protocol" header with a list
  /// of protocols to [request].
  ///
  /// See [NSURLSession webSocketTaskWithRequest:](https://developer.apple.com/documentation/foundation/nsurlsession/3235750-websockettaskwithrequest)
  URLSessionWebSocketTask webSocketTaskWithRequest(URLRequest request) {
    if (_isBackground) {
      throw UnsupportedError(
        'WebSocket tasks are not supported in background sessions',
      );
    }
    return URLSessionWebSocketTask._(
      _nsObject.webSocketTaskWithRequest(request._nsObject),
    );
  }

  /// Creates a [URLSessionWebSocketTask] that represents a connection to a
  /// WebSocket endpoint.
  ///
  /// See [NSURLSession webSocketTaskWithURL:protocols:](https://developer.apple.com/documentation/foundation/nsurlsession/3181172-websockettaskwithurl)
  URLSessionWebSocketTask webSocketTaskWithURL(
    Uri uri, {
    Iterable<String>? protocols,
  }) {
    if (_isBackground) {
      throw UnsupportedError(
        'WebSocket tasks are not supported in background sessions',
      );
    }
    final URLSessionWebSocketTask task;
    if (protocols == null) {
      task = URLSessionWebSocketTask._(
        _nsObject.webSocketTaskWithURL(_uriToNSURL(uri)),
      );
    } else {
      task = URLSessionWebSocketTask._(
        _nsObject.webSocketTaskWithURL$1(
          _uriToNSURL(uri),
          protocols: objc.toObjCObject(protocols) as objc.NSArray,
        ),
      );
    }
    return task;
  }

  /// Free resources related to this session after the last task completes.
  /// Returns immediately.
  ///
  /// See [NSURLSession finishTasksAndInvalidate](https://developer.apple.com/documentation/foundation/nsurlsession/1407428-finishtasksandinvalidate)
  void finishTasksAndInvalidate() {
    _nsObject.finishTasksAndInvalidate();
  }
}
