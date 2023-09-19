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
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:ffi/ffi.dart';

import 'native_cupertino_bindings.dart' as ncb;
import 'utils.dart';

abstract class _ObjectHolder<T extends ncb.NSObject> {
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

/// Settings for controlling whether cookies will be accepted.
///
/// See [HTTPCookieAcceptPolicy](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1408933-httpcookieacceptpolicy).
enum HTTPCookieAcceptPolicy {
  httpCookieAcceptPolicyAlways,
  httpCookieAcceptPolicyNever,
  httpCookieAcceptPolicyOnlyFromMainDocumentDomain,
}

/// Controls how response data is cached.
///
/// See [URLRequestCachePolicy](https://developer.apple.com/documentation/foundation/nsurlrequestcachepolicy).
enum URLRequestCachePolicy {
  useProtocolCachePolicy,
  reloadIgnoringLocalCacheData,
  returnCacheDataElseLoad,
  returnCacheDataDontLoad,
  reloadIgnoringLocalAndRemoteCacheData,
  reloadRevalidatingCacheData,
}

// Controls how multipath TCP should be used.
//
// See [NSURLSessionMultipathServiceType](https://developer.apple.com/documentation/foundation/nsurlsessionmultipathservicetype).
enum URLSessionMultipathServiceType {
  multipathServiceTypeNone,
  multipathServiceTypeHandover,
  multipathServiceTypeInteractive,
  multipathServiceTypeAggregate,
}

/// Controls how [URLSessionTask] execute will proceed after the response is
/// received.
///
/// See [NSURLSessionResponseDisposition](https://developer.apple.com/documentation/foundation/nsurlsessionresponsedisposition).
enum URLSessionResponseDisposition {
  urlSessionResponseCancel,
  urlSessionResponseAllow,
  urlSessionResponseBecomeDownload,
  urlSessionResponseBecomeStream
}

/// Provides in indication to the operating system on what type of requests
/// are being sent.
///
/// See [NSURLRequestNetworkServiceType](https://developer.apple.com/documentation/foundation/nsurlrequestnetworkservicetype).
enum URLRequestNetworkService {
  networkServiceTypeDefault,
  networkServiceTypeVoIP,
  networkServiceTypeVideo,
  networkServiceTypeBackground,
  networkServiceTypeVoice,
  networkServiceTypeResponsiveData,
  networkServiceTypeAVStreaming,
  networkServiceTypeResponsiveAV,
  networkServiceTypeCallSignaling
}

/// The type of a WebSocket message i.e. text or data.
///
/// See [NSURLSessionWebSocketMessageType](https://developer.apple.com/documentation/foundation/nsurlsessionwebsocketmessagetype)
enum URLSessionWebSocketMessageType {
  urlSessionWebSocketMessageTypeData,
  urlSessionWebSocketMessageTypeString,
}

ncb.NSInputStream _streamToNSInputStream(Stream<List<int>> stream) {
  const maxReadAheadSize = 4096;
  final queue = StreamQueue(stream);
  final port = ReceivePort();
  final inputStream = ncb.CUPHTTPStreamToNSInputStreamAdapter.alloc(helperLibs)
      .initWithPort_(port.sendPort.nativePort);

  late StreamSubscription<dynamic> s;
  // Messages from `CUPHTTPStreamToNSInputStreamAdapter` indicate that the task
  // is attempting to read more data but there is none available.
  s = port.listen((_) async {
    if (inputStream.streamStatus == ncb.NSStreamStatus.NSStreamStatusClosed) {
      return;
    }

    // Prevent multiple executions of this code to be in flight at once.
    s.pause();
    while (await queue.hasNext &&
        inputStream.streamStatus != ncb.NSStreamStatus.NSStreamStatusClosed) {
      late final List<int> next;
      try {
        next = await queue.next;
      } catch (e) {
        inputStream.setError_(Error.fromCustomDomain('DartError', 0,
                localizedDescription: e.toString())
            ._nsObject);
        break;
      }
      // In practice the read length request will be large (>1MB) so,
      // instead of adding that much data, try to keep the buffer
      // at least `maxReadAheadSize`.
      if (inputStream.addData_(Data.fromList(next)._nsObject) >
          maxReadAheadSize) {
        break;
      }
    }
    if (!await queue.hasNext) {
      inputStream.setDone();
    } else {
      s.resume();
    }
  });
  return inputStream;
}

/// Information about a failure.
///
/// See [NSError](https://developer.apple.com/documentation/foundation/nserror)
class Error extends _ObjectHolder<ncb.NSError> implements Exception {
  Error._(super.c);

  /// Create an Error from a custom domain.
  factory Error.fromCustomDomain(String domain, int code,
      {String? localizedDescription}) {
    final d = ncb.NSMutableDictionary.alloc(linkedLibs).init();

    if (localizedDescription != null) {
      d.setObject_forKey_(
        localizedDescription.toNSString(linkedLibs),
        ncb.NSString.castFromPointer(
            linkedLibs, linkedLibs.NSLocalizedDescriptionKey),
      );
    }
    final e = ncb.NSError.alloc(linkedLibs).initWithDomain_code_userInfo_(
        domain.toNSString(linkedLibs).pointer, code, d);
    return Error._(e);
  }

  /// The numeric code for the error e.g. -1003 (kCFURLErrorCannotFindHost).
  ///
  /// The interpretation of this code will depend on the domain of the error
  /// which, for URL loading, will usually be
  /// [`kCFErrorDomainCFNetwork`](https://developer.apple.com/documentation/cfnetwork/kcferrordomaincfnetwork).
  ///
  /// See [NSError.code](https://developer.apple.com/documentation/foundation/nserror/1409165-code)
  int get code => _nsObject.code;

  /// The error domain, for example `"NSPOSIXErrorDomain"`.
  ///
  /// See [NSError.domain](https://developer.apple.com/documentation/foundation/nserror/1413924-domain)
  String get domain =>
      ncb.NSString.castFromPointer(linkedLibs, _nsObject.domain).toString();

  /// A description of the error in the current locale e.g.
  /// 'A server with the specified hostname could not be found.'
  ///
  /// See [NSError.localizedDescription](https://developer.apple.com/documentation/foundation/nserror/1414418-localizeddescription)
  String? get localizedDescription =>
      toStringOrNull(_nsObject.localizedDescription);

  /// An explanation of the reason for the error in the current locale.
  ///
  /// See [NSError.localizedFailureReason](https://developer.apple.com/documentation/foundation/nserror/1412752-localizedfailurereason)
  String? get localizedFailureReason =>
      toStringOrNull(_nsObject.localizedFailureReason);

  /// An explanation of how to fix the error in the current locale.
  ///
  /// See [NSError.localizedRecoverySuggestion](https://developer.apple.com/documentation/foundation/nserror/1407500-localizedrecoverysuggestion)
  String? get localizedRecoverySuggestion =>
      toStringOrNull(_nsObject.localizedRecoverySuggestion);

  @override
  String toString() => '[Error '
      'domain=$domain '
      'code=$code '
      'localizedDescription=$localizedDescription '
      'localizedFailureReason=$localizedFailureReason '
      'localizedRecoverySuggestion=$localizedRecoverySuggestion '
      ']';
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
    final sharedCache = ncb.NSURLCache.getSharedURLCache(linkedLibs);
    return sharedCache == null ? null : URLCache._(sharedCache);
  }

  /// Create a new [URLCache] with the given memory and disk cache sizes.
  ///
  /// [memoryCapacity] and [diskCapacity] are specified in bytes.
  ///
  /// [directory] is the file system location where the disk cache will be
  /// stored. If `null` then the default directory will be used.
  ///
  /// See [NSURLCache initWithMemoryCapacity:diskCapacity:directoryURL:](https://developer.apple.com/documentation/foundation/nsurlcache/3240612-initwithmemorycapacity)
  factory URLCache.withCapacity(
          {int memoryCapacity = 0, int diskCapacity = 0, Uri? directory}) =>
      URLCache._(ncb.NSURLCache.alloc(linkedLibs)
          .initWithMemoryCapacity_diskCapacity_directoryURL_(memoryCapacity,
              diskCapacity, directory == null ? null : uriToNSURL(directory)));
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
  factory URLSessionConfiguration.backgroundSession(String identifier) =>
      URLSessionConfiguration._(
          ncb.NSURLSessionConfiguration
              .backgroundSessionConfigurationWithIdentifier_(
                  linkedLibs, identifier.toNSString(linkedLibs)),
          isBackground: true);

  /// A configuration that uses caching and saves cookies and credentials.
  ///
  /// See [NSURLSessionConfiguration defaultSessionConfiguration](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1411560-defaultsessionconfiguration)
  factory URLSessionConfiguration.defaultSessionConfiguration() =>
      URLSessionConfiguration._(
          ncb.NSURLSessionConfiguration.castFrom(
              ncb.NSURLSessionConfiguration.getDefaultSessionConfiguration(
                  linkedLibs)!),
          isBackground: false);

  /// A session configuration that uses no persistent storage for caches,
  /// cookies, or credentials.
  ///
  /// See [NSURLSessionConfiguration ephemeralSessionConfiguration](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1410529-ephemeralsessionconfiguration)
  factory URLSessionConfiguration.ephemeralSessionConfiguration() =>
      URLSessionConfiguration._(
          ncb.NSURLSessionConfiguration.castFrom(
              ncb.NSURLSessionConfiguration.getEphemeralSessionConfiguration(
                  linkedLibs)!),
          isBackground: false);

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
  bool get discretionary => _nsObject.discretionary;
  set discretionary(bool value) => _nsObject.discretionary = value;

  /// What policy to use when deciding whether to accept cookies.
  ///
  /// See [NSURLSessionConfiguration.HTTPCookieAcceptPolicy](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1408933-httpcookieacceptpolicy).
  HTTPCookieAcceptPolicy get httpCookieAcceptPolicy =>
      HTTPCookieAcceptPolicy.values[_nsObject.HTTPCookieAcceptPolicy];
  set httpCookieAcceptPolicy(HTTPCookieAcceptPolicy value) =>
      _nsObject.HTTPCookieAcceptPolicy = value.index;

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
  URLSessionMultipathServiceType get multipathServiceType =>
      URLSessionMultipathServiceType.values[_nsObject.multipathServiceType];
  set multipathServiceType(URLSessionMultipathServiceType value) =>
      _nsObject.multipathServiceType = value.index;

  /// Provides in indication to the operating system on what type of requests
  /// are being sent.
  ///
  /// See [NSURLSessionConfiguration.networkServiceType](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1411606-networkservicetype).
  URLRequestNetworkService get networkServiceType =>
      URLRequestNetworkService.values[_nsObject.networkServiceType];
  set networkServiceType(URLRequestNetworkService value) =>
      _nsObject.networkServiceType = value.index;

  /// Controls how to deal with response caching.
  ///
  /// See [NSURLSessionConfiguration.requestCachePolicy](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1411655-requestcachepolicy)
  URLRequestCachePolicy get requestCachePolicy =>
      URLRequestCachePolicy.values[_nsObject.requestCachePolicy];
  set requestCachePolicy(URLRequestCachePolicy value) =>
      _nsObject.requestCachePolicy = value.index;

  /// Whether the app should be resumed when background tasks complete.
  ///
  /// See [NSURLSessionConfiguration.sessionSendsLaunchEvents](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1617174-sessionsendslaunchevents)
  bool get sessionSendsLaunchEvents => _nsObject.sessionSendsLaunchEvents;
  set sessionSendsLaunchEvents(bool value) =>
      _nsObject.sessionSendsLaunchEvents = value;

  /// Whether connections will be preserved if the app moves to the background.
  ///
  /// See [NSURLSessionConfiguration.shouldUseExtendedBackgroundIdleMode](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1409517-shoulduseextendedbackgroundidlem)
  bool get shouldUseExtendedBackgroundIdleMode =>
      _nsObject.shouldUseExtendedBackgroundIdleMode;
  set shouldUseExtendedBackgroundIdleMode(bool value) =>
      _nsObject.shouldUseExtendedBackgroundIdleMode = value;

  /// The timeout interval if data is not received.
  ///
  /// See [NSURLSessionConfiguration.timeoutIntervalForRequest](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1408259-timeoutintervalforrequest)
  Duration get timeoutIntervalForRequest => Duration(
      microseconds:
          (_nsObject.timeoutIntervalForRequest * Duration.microsecondsPerSecond)
              .round());

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
  String toString() => '[URLSessionConfiguration '
      'allowsCellularAccess=$allowsCellularAccess '
      'allowsConstrainedNetworkAccess=$allowsConstrainedNetworkAccess '
      'allowsExpensiveNetworkAccess=$allowsExpensiveNetworkAccess '
      'discretionary=$discretionary '
      'httpCookieAcceptPolicy=$httpCookieAcceptPolicy '
      'httpShouldSetCookies=$httpShouldSetCookies '
      'httpMaximumConnectionsPerHost=$httpMaximumConnectionsPerHost '
      'httpShouldUsePipelining=$httpShouldUsePipelining '
      'requestCachePolicy=$requestCachePolicy '
      'sessionSendsLaunchEvents=$sessionSendsLaunchEvents '
      'shouldUseExtendedBackgroundIdleMode='
      '$shouldUseExtendedBackgroundIdleMode '
      'timeoutIntervalForRequest=$timeoutIntervalForRequest '
      'waitsForConnectivity=$waitsForConnectivity'
      ']';
}

/// A container for byte data.
///
/// See [NSData](https://developer.apple.com/documentation/foundation/nsdata)
class Data extends _ObjectHolder<ncb.NSData> {
  Data._(super.c);

  /// A new [Data] from an existing one.
  ///
  /// See [NSData dataWithData:](https://developer.apple.com/documentation/foundation/nsdata/1547230-datawithdata)
  factory Data.fromData(Data d) =>
      Data._(ncb.NSData.dataWithData_(linkedLibs, d._nsObject));

  /// A new [Data] object containing the given bytes.
  factory Data.fromList(List<int> l) {
    final buffer = calloc<Uint8>(l.length);
    try {
      buffer.asTypedList(l.length).setAll(0, l);

      final data =
          ncb.NSData.dataWithBytes_length_(linkedLibs, buffer.cast(), l.length);
      return Data._(data);
    } finally {
      calloc.free(buffer);
    }
  }

  /// A new [Data] object containing the given bytes.
  @Deprecated('Use Data.fromList instead')
  factory Data.fromUint8List(Uint8List l) = Data.fromList;

  /// The number of bytes contained in the object.
  ///
  /// See [NSData.length](https://developer.apple.com/documentation/foundation/nsdata/1416769-length)
  int get length => _nsObject.length;

  /// The data contained in the object.
  ///
  /// See [NSData.bytes](https://developer.apple.com/documentation/foundation/nsdata/1410616-bytes)
  Uint8List get bytes {
    final bytes = _nsObject.bytes;
    if (bytes.address == 0) {
      return Uint8List(0);
    } else {
      // `NSData.byte` has the same lifetime as the `NSData` so make a copy to
      // ensure memory safety.
      // TODO(https://github.com/dart-lang/ffigen/issues/375): Remove copy.
      return Uint8List.fromList(bytes.cast<Uint8>().asTypedList(length));
    }
  }

  @override
  String toString() {
    final subrange =
        length == 0 ? Uint8List(0) : bytes.sublist(0, min(length - 1, 20));
    final b = subrange.map((e) => e.toRadixString(16)).join();
    return '[Data length=$length bytes=0x$b...]';
  }
}

/// A container for byte data.
///
/// See [NSMutableData](https://developer.apple.com/documentation/foundation/nsmutabledata)
class MutableData extends Data {
  final ncb.NSMutableData _mutableData;

  MutableData._(ncb.NSMutableData super.c)
      : _mutableData = c,
        super._();

  /// A new empty [MutableData].
  factory MutableData.empty() =>
      MutableData._(ncb.NSMutableData.dataWithCapacity_(linkedLibs, 0));

  /// Appends the given data.
  ///
  /// See [NSMutableData appendBytes:length:](https://developer.apple.com/documentation/foundation/nsmutabledata/1407704-appendbytes)
  void appendBytes(List<int> l) {
    final f = calloc<Uint8>(l.length);
    try {
      f.asTypedList(l.length).setAll(0, l);

      _mutableData.appendBytes_length_(f.cast(), l.length);
    } finally {
      calloc.free(f);
    }
  }

  @override
  String toString() {
    final subrange =
        length == 0 ? Uint8List(0) : bytes.sublist(0, min(length - 1, 20));
    final b = subrange.map((e) => e.toRadixString(16)).join();
    return '[MutableData length=$length bytes=0x$b...]';
  }
}

/// The response associated with loading an URL.
///
/// See [NSURLResponse](https://developer.apple.com/documentation/foundation/nsurlresponse)
class URLResponse extends _ObjectHolder<ncb.NSURLResponse> {
  URLResponse._(super.c);

  factory URLResponse._exactURLResponseType(ncb.NSURLResponse response) {
    if (ncb.NSHTTPURLResponse.isInstance(response)) {
      return HTTPURLResponse._(ncb.NSHTTPURLResponse.castFrom(response));
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
  String? get mimeType => toStringOrNull(_nsObject.MIMEType);

  @override
  String toString() => '[URLResponse '
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
  Map<String, String> get allHeaderFields {
    final headers =
        ncb.NSDictionary.castFrom(_httpUrlResponse.allHeaderFields!);
    return stringDictToMap(headers);
  }

  @override
  String toString() => '[HTTPURLResponse '
      'statusCode=$statusCode '
      'mimeType=$mimeType '
      'expectedContentLength=$expectedContentLength'
      ']';
}

/// The possible states of a [URLSessionTask].
///
/// See [NSURLSessionTaskState](https://developer.apple.com/documentation/foundation/nsurlsessiontaskstate)
enum URLSessionTaskState {
  urlSessionTaskStateRunning,
  urlSessionTaskStateSuspended,
  urlSessionTaskStateCanceling,
  urlSessionTaskStateCompleted,
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
  factory URLSessionWebSocketMessage.fromData(Data d) =>
      URLSessionWebSocketMessage._(
          ncb.NSURLSessionWebSocketMessage.alloc(linkedLibs)
              .initWithData_(d._nsObject));

  /// Create a WebSocket string message.
  ///
  /// See [NSURLSessionWebSocketMessage initWitString:](https://developer.apple.com/documentation/foundation/nsurlsessionwebsocketmessage/3181193-initwithstring)
  factory URLSessionWebSocketMessage.fromString(String s) =>
      URLSessionWebSocketMessage._(
          ncb.NSURLSessionWebSocketMessage.alloc(linkedLibs)
              .initWithString_(s.toNSString(linkedLibs)));

  /// The data associated with the WebSocket message.
  ///
  /// Will be `null` if the [URLSessionWebSocketMessage] is a string message.
  ///
  /// See [NSURLSessionWebSocketMessage.data](https://developer.apple.com/documentation/foundation/nsurlsessionwebsocketmessage/3181191-data)
  Data? get data => _nsObject.data == null ? null : Data._(_nsObject.data!);

  /// The string associated with the WebSocket message.
  ///
  /// Will be `null` if the [URLSessionWebSocketMessage] is a data message.
  ///
  /// See [NSURLSessionWebSocketMessage.string](https://developer.apple.com/documentation/foundation/nsurlsessionwebsocketmessage/3181194-string)
  String? get string => toStringOrNull(_nsObject.string);

  /// The type of the WebSocket message.
  ///
  /// See [NSURLSessionWebSocketMessage.type](https://developer.apple.com/documentation/foundation/nsurlsessionwebsocketmessage/3181195-type)
  URLSessionWebSocketMessageType get type =>
      URLSessionWebSocketMessageType.values[_nsObject.type];

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
  URLSessionTaskState get state => URLSessionTaskState.values[_nsObject.state];

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
  Error? get error {
    final error = _nsObject.error;
    if (error == null) {
      return null;
    } else {
      return Error._(error);
    }
  }

  /// The user-assigned description for the task.
  ///
  /// See [NSURLSessionTask.taskDescription](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1409798-taskdescription)
  String get taskDescription => _nsObject.taskDescription.toString();

  /// The user-assigned description for the task.
  ///
  /// See [NSURLSessionTask.taskDescription](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1409798-taskdescription)
  set taskDescription(String value) =>
      _nsObject.taskDescription = value.toNSString(linkedLibs);

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

  String _toStringHelper(String className) => '[$className '
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
  Data? get closeReason {
    final reason = _urlSessionWebSocketTask.closeReason;
    if (reason == null) {
      return null;
    } else {
      return Data._(reason);
    }
  }

  /// Sends a single WebSocket message.
  ///
  /// The returned future will complete successfully when the message is sent
  /// and with an [Error] on failure.
  ///
  /// See [NSURLSessionWebSocketTask.sendMessage:completionHandler:](https://developer.apple.com/documentation/foundation/nsurlsessionwebsockettask/3181205-sendmessage)
  Future<void> sendMessage(URLSessionWebSocketMessage message) async {
    final completer = Completer<void>();
    final completionPort = ReceivePort();
    completionPort.listen((message) {
      final ep = Pointer<ncb.ObjCObject>.fromAddress(message as int);
      if (ep.address == 0) {
        completer.complete();
      } else {
        final error = Error._(ncb.NSError.castFromPointer(linkedLibs, ep,
            retain: false, release: true));
        completer.completeError(error);
      }
      completionPort.close();
    });

    helperLibs.CUPHTTPSendMessage(_urlSessionWebSocketTask.pointer,
        message._nsObject.pointer, completionPort.sendPort.nativePort);
    await completer.future;
  }

  /// Receives a single WebSocket message.
  ///
  /// Throws an [Error] on failure.
  ///
  /// See [NSURLSessionWebSocketTask.receiveMessageWithCompletionHandler:](https://developer.apple.com/documentation/foundation/nsurlsessionwebsockettask/3181204-receivemessagewithcompletionhand)
  Future<URLSessionWebSocketMessage> receiveMessage() async {
    final completer = Completer<URLSessionWebSocketMessage>();
    final completionPort = ReceivePort();
    completionPort.listen((d) {
      final messageAndError = d as List;

      final mp = Pointer<ncb.ObjCObject>.fromAddress(messageAndError[0] as int);
      final ep = Pointer<ncb.ObjCObject>.fromAddress(messageAndError[1] as int);

      final message = mp.address == 0
          ? null
          : URLSessionWebSocketMessage._(
              ncb.NSURLSessionWebSocketMessage.castFromPointer(linkedLibs, mp,
                  retain: false, release: true));
      final error = ep.address == 0
          ? null
          : Error._(ncb.NSError.castFromPointer(linkedLibs, ep,
              retain: false, release: true));

      if (error != null) {
        completer.completeError(error);
      } else {
        completer.complete(message!);
      }
      completionPort.close();
    });

    helperLibs.CUPHTTPReceiveMessage(
        _urlSessionWebSocketTask.pointer, completionPort.sendPort.nativePort);
    return completer.future;
  }

  /// Sends close frame with the given code and optional reason.
  ///
  /// See [NSURLSessionWebSocketTask.cancelWithCloseCode:reason:](https://developer.apple.com/documentation/foundation/nsurlsessionwebsockettask/3181200-cancelwithclosecode)
  void cancelWithCloseCode(int closeCode, Data? reason) {
    _urlSessionWebSocketTask.cancelWithCloseCode_reason_(
        closeCode, reason?._nsObject);
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
  factory URLRequest.fromUrl(Uri uri) => URLRequest._(
      ncb.NSURLRequest.requestWithURL_(linkedLibs, uriToNSURL(uri)));

  /// Returns all of the HTTP headers for the request.
  ///
  /// See [NSURLRequest.allHTTPHeaderFields](https://developer.apple.com/documentation/foundation/nsurlrequest/1418477-allhttpheaderfields)
  Map<String, String>? get allHttpHeaderFields {
    if (_nsObject.allHTTPHeaderFields == null) {
      return null;
    } else {
      final headers = ncb.NSDictionary.castFrom(_nsObject.allHTTPHeaderFields!);
      return stringDictToMap(headers);
    }
  }

  /// Controls how to deal with caching for the request.
  ///
  /// See [NSURLSession.cachePolicy](https://developer.apple.com/documentation/foundation/nsurlrequest/1407944-cachepolicy)
  URLRequestCachePolicy get cachePolicy =>
      URLRequestCachePolicy.values[_nsObject.cachePolicy];

  /// The body of the request.
  ///
  /// See [NSURLRequest.HTTPBody](https://developer.apple.com/documentation/foundation/nsurlrequest/1411317-httpbody)
  Data? get httpBody {
    final body = _nsObject.HTTPBody;
    if (body == null) {
      return null;
    }
    return Data._(ncb.NSData.castFrom(body));
  }

  /// The HTTP request method (e.g. 'GET').
  ///
  /// See [NSURLRequest.HTTPMethod](https://developer.apple.com/documentation/foundation/nsurlrequest/1413030-httpmethod)
  ///
  /// NOTE: The documentation for `NSURLRequest.HTTPMethod` says that the
  /// property is nullable but, in practice, assigning it to null will produce
  /// an error.
  String get httpMethod => _nsObject.HTTPMethod!.toString();

  /// The timeout interval during the connection attempt.
  ///
  /// See [NSURLSession.timeoutInterval](https://developer.apple.com/documentation/foundation/nsurlrequest/1418229-timeoutinterval)
  Duration get timeoutInterval => Duration(
      microseconds:
          (_nsObject.timeoutInterval * Duration.microsecondsPerSecond).round());

  /// The requested URL.
  ///
  /// See [URLRequest.URL](https://developer.apple.com/documentation/foundation/nsurlrequest/1408996-url)
  Uri? get url {
    final nsUrl = _nsObject.URL;
    if (nsUrl == null) {
      return null;
    }
    return Uri.parse(nsUrl.absoluteString!.toString());
  }

  @override
  String toString() => '[URLRequest '
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
    final url = ncb.NSURL
        .URLWithString_(linkedLibs, uri.toString().toNSString(linkedLibs));
    return MutableURLRequest._(
        ncb.NSMutableURLRequest.requestWithURL_(linkedLibs, url));
  }

  set cachePolicy(URLRequestCachePolicy value) =>
      _mutableUrlRequest.cachePolicy = value.index;

  set httpBody(Data? data) {
    _mutableUrlRequest.HTTPBody = data?._nsObject;
  }

  /// Sets the body of the request to the given [Stream].
  ///
  /// See [NSMutableURLRequest.HTTPBodyStream](https://developer.apple.com/documentation/foundation/nsurlrequest/1407341-httpbodystream).
  set httpBodyStream(Stream<List<int>> stream) {
    _mutableUrlRequest.HTTPBodyStream = _streamToNSInputStream(stream);
  }

  set httpMethod(String method) {
    _mutableUrlRequest.HTTPMethod = method.toNSString(linkedLibs);
  }

  set timeoutInterval(Duration interval) {
    _mutableUrlRequest.timeoutInterval =
        interval.inMicroseconds.toDouble() / Duration.microsecondsPerSecond;
  }

  /// Set the value of a header field.
  ///
  /// See [NSMutableURLRequest setValue:forHTTPHeaderField:](https://developer.apple.com/documentation/foundation/nsmutableurlrequest/1408793-setvalue)
  void setValueForHttpHeaderField(String value, String field) {
    _mutableUrlRequest.setValue_forHTTPHeaderField_(
        field.toNSString(linkedLibs), value.toNSString(linkedLibs));
  }

  @override
  String toString() => '[MutableURLRequest '
      'allHttpHeaderFields=$allHttpHeaderFields '
      'cachePolicy=$cachePolicy '
      'httpBody=$httpBody '
      'httpMethod=$httpMethod '
      'timeoutInterval=$timeoutInterval '
      'url=$url '
      ']';
}

/// Setup delegation for the given [task] to the given methods.
///
/// Specifically, this causes the Objective-C-implemented delegate installed
/// with
/// [sessionWithConfiguration:delegate:delegateQueue:](https://developer.apple.com/documentation/foundation/nsurlsession/1411597-sessionwithconfiguration)
/// to send a [ncb.CUPHTTPForwardedDelegate] object to a send port, which is
/// then processed by [_setupDelegation] and forwarded to the given methods.
void _setupDelegation(
  ncb.CUPHTTPClientDelegate delegate,
  URLSession session,
  URLSessionTask task, {
  URLRequest? Function(URLSession session, URLSessionTask task,
          HTTPURLResponse response, URLRequest newRequest)?
      onRedirect,
  URLSessionResponseDisposition Function(
          URLSession session, URLSessionTask task, URLResponse response)?
      onResponse,
  void Function(URLSession session, URLSessionTask task, Data error)? onData,
  void Function(URLSession session, URLSessionDownloadTask task, Uri uri)?
      onFinishedDownloading,
  void Function(URLSession session, URLSessionTask task, Error? error)?
      onComplete,
  void Function(
          URLSession session, URLSessionWebSocketTask task, String? protocol)?
      onWebSocketTaskOpened,
  void Function(URLSession session, URLSessionWebSocketTask task, int closeCode,
          Data? reason)?
      onWebSocketTaskClosed,
}) {
  final responsePort = ReceivePort();
  responsePort.listen((d) {
    final message = d as List;
    final messageType = message[0];
    final dp = Pointer<ncb.ObjCObject>.fromAddress(message[1] as int);

    final forwardedDelegate = ncb.CUPHTTPForwardedDelegate.castFromPointer(
        helperLibs, dp,
        retain: true, release: true);

    switch (messageType) {
      case ncb.MessageType.RedirectMessage:
        final forwardedRedirect =
            ncb.CUPHTTPForwardedRedirect.castFrom(forwardedDelegate);
        URLRequest? redirectRequest;

        try {
          final request = URLRequest._(
              ncb.NSURLRequest.castFrom(forwardedRedirect.request!));

          if (onRedirect == null) {
            redirectRequest = request;
            break;
          }
          try {
            final response = HTTPURLResponse._(
                ncb.NSHTTPURLResponse.castFrom(forwardedRedirect.response!));
            redirectRequest = onRedirect(session, task, response, request);
          } catch (e) {
            // TODO(https://github.com/dart-lang/ffigen/issues/386): Package
            // this exception as an `Error` and call the completion function
            // with it.
          }
        } finally {
          forwardedRedirect.finishWithRequest_(redirectRequest?._nsObject);
        }
        break;
      case ncb.MessageType.ResponseMessage:
        final forwardedResponse =
            ncb.CUPHTTPForwardedResponse.castFrom(forwardedDelegate);
        var disposition =
            URLSessionResponseDisposition.urlSessionResponseCancel;

        try {
          if (onResponse == null) {
            disposition = URLSessionResponseDisposition.urlSessionResponseAllow;
            break;
          }
          final response =
              URLResponse._exactURLResponseType(forwardedResponse.response!);

          try {
            disposition = onResponse(session, task, response);
          } catch (e) {
            // TODO(https://github.com/dart-lang/ffigen/issues/386): Package
            // this exception as an `Error` and call the completion function
            // with it.
          }
        } finally {
          forwardedResponse.finishWithDisposition_(disposition.index);
        }
        break;
      case ncb.MessageType.DataMessage:
        final forwardedData =
            ncb.CUPHTTPForwardedData.castFrom(forwardedDelegate);

        try {
          if (onData == null) {
            break;
          }
          try {
            onData(session, task,
                Data._(ncb.NSData.castFrom(forwardedData.data!)));
          } catch (e) {
            // TODO(https://github.com/dart-lang/ffigen/issues/386): Package
            // this exception as an `Error` and call the completion function
            // with it.
          }
        } finally {
          forwardedData.finish();
        }
        break;
      case ncb.MessageType.FinishedDownloading:
        final finishedDownloading =
            ncb.CUPHTTPForwardedFinishedDownloading.castFrom(forwardedDelegate);
        try {
          if (onFinishedDownloading == null) {
            break;
          }
          try {
            onFinishedDownloading(
                session,
                task as URLSessionDownloadTask,
                Uri.parse(
                    finishedDownloading.location!.absoluteString!.toString()));
          } catch (e) {
            // TODO(https://github.com/dart-lang/ffigen/issues/386): Package
            // this exception as an `Error` and call the completion function
            // with it.
          }
        } finally {
          finishedDownloading.finish();
        }
        break;
      case ncb.MessageType.CompletedMessage:
        final forwardedComplete =
            ncb.CUPHTTPForwardedComplete.castFrom(forwardedDelegate);

        try {
          if (onComplete == null) {
            break;
          }
          Error? error;
          if (forwardedComplete.error != null) {
            error = Error._(ncb.NSError.castFrom(forwardedComplete.error!));
          }
          try {
            onComplete(session, task, error);
          } catch (e) {
            // TODO(https://github.com/dart-lang/ffigen/issues/386): Package
            // this exception as an `Error` and call the completion function
            // with it.
          }
        } finally {
          forwardedComplete.finish();
          responsePort.close();
        }
        break;
      case ncb.MessageType.WebSocketOpened:
        final webSocketOpened =
            ncb.CUPHTTPForwardedWebSocketOpened.castFrom(forwardedDelegate);

        try {
          if (onWebSocketTaskOpened == null) {
            break;
          }
          try {
            onWebSocketTaskOpened(session, task as URLSessionWebSocketTask,
                webSocketOpened.protocol?.toString());
          } catch (e) {
            // TODO(https://github.com/dart-lang/ffigen/issues/386): Package
            // this exception as an `Error` and call the completion function
            // with it.
          }
        } finally {
          webSocketOpened.finish();
        }
        break;
      case ncb.MessageType.WebSocketClosed:
        final webSocketClosed =
            ncb.CUPHTTPForwardedWebSocketClosed.castFrom(forwardedDelegate);

        try {
          if (onWebSocketTaskClosed == null) {
            break;
          }
          try {
            onWebSocketTaskClosed(
                session,
                task as URLSessionWebSocketTask,
                webSocketClosed.closeCode,
                webSocketClosed.reason == null
                    ? null
                    : Data._(webSocketClosed.reason!));
          } catch (e) {
            // TODO(https://github.com/dart-lang/ffigen/issues/386): Package
            // this exception as an `Error` and call the completion function
            // with it.
          }
        } finally {
          webSocketClosed.finish();
        }
        break;
    }
  });
  final config = ncb.CUPHTTPTaskConfiguration.castFrom(
      ncb.CUPHTTPTaskConfiguration.alloc(helperLibs)
          .initWithPort_(responsePort.sendPort.nativePort));

  delegate.registerTask_withConfiguration_(task._nsObject, config);
}

/// A client that can make network requests to a server.
///
/// See [NSURLSession](https://developer.apple.com/documentation/foundation/nsurlsession)
class URLSession extends _ObjectHolder<ncb.NSURLSession> {
  // Provide our own native delegate to `NSURLSession` because delegates can be
  // called on arbitrary threads and Dart code cannot be.
  static final _delegate = ncb.CUPHTTPClientDelegate.new1(helperLibs);
  // Indicates if the session is a background session. Copied from the
  // [URLSessionConfiguration._isBackground] associated with this [URLSession].
  final bool _isBackground;

  final URLRequest? Function(URLSession session, URLSessionTask task,
      HTTPURLResponse response, URLRequest newRequest)? _onRedirect;
  final URLSessionResponseDisposition Function(
          URLSession session, URLSessionTask task, URLResponse response)?
      _onResponse;
  final void Function(URLSession session, URLSessionTask task, Data error)?
      _onData;
  final void Function(URLSession session, URLSessionTask task, Error? error)?
      _onComplete;
  final void Function(URLSession session, URLSessionDownloadTask task, Uri uri)?
      _onFinishedDownloading;
  final void Function(
          URLSession session, URLSessionWebSocketTask task, String? protocol)?
      _onWebSocketTaskOpened;
  final void Function(URLSession session, URLSessionWebSocketTask task,
      int closeCode, Data? reason)? _onWebSocketTaskClosed;

  URLSession._(
    super.c, {
    required bool isBackground,
    URLRequest? Function(URLSession session, URLSessionTask task,
            HTTPURLResponse response, URLRequest newRequest)?
        onRedirect,
    URLSessionResponseDisposition Function(
            URLSession session, URLSessionTask task, URLResponse response)?
        onResponse,
    void Function(URLSession session, URLSessionTask task, Data error)? onData,
    void Function(URLSession session, URLSessionDownloadTask task, Uri uri)?
        onFinishedDownloading,
    void Function(URLSession session, URLSessionTask task, Error? error)?
        onComplete,
    void Function(
            URLSession session, URLSessionWebSocketTask task, String? protocol)?
        onWebSocketTaskOpened,
    void Function(URLSession session, URLSessionWebSocketTask task,
            int closeCode, Data? reason)?
        onWebSocketTaskClosed,
  })  : _isBackground = isBackground,
        _onRedirect = onRedirect,
        _onResponse = onResponse,
        _onData = onData,
        _onFinishedDownloading = onFinishedDownloading,
        _onComplete = onComplete,
        _onWebSocketTaskOpened = onWebSocketTaskOpened,
        _onWebSocketTaskClosed = onWebSocketTaskClosed;

  /// A client with reasonable default behavior.
  ///
  /// See [NSURLSession.sharedSession](https://developer.apple.com/documentation/foundation/nsurlsession/1409000-sharedsession)
  factory URLSession.sharedSession() => URLSession.sessionWithConfiguration(
      URLSessionConfiguration.defaultSessionConfiguration());

  /// A client with a given configuration.
  ///
  /// If [onRedirect] is set then it will be called whenever a HTTP
  /// request returns a redirect response (e.g. 302). The `response` parameter
  /// contains the response from the server. The `newRequest` parameter contains
  /// a follow-up request that would honor the server's redirect. If the return
  /// value of this function is `null` then the redirect will not occur.
  /// Otherwise, the returned [URLRequest] (usually `newRequest`) will be
  /// executed. [onRedirect] will not be called for background sessions, which
  /// automatically follow redirects. See
  /// [URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:](https://developer.apple.com/documentation/foundation/nsurlsessiontaskdelegate/1411626-urlsession)
  ///
  /// If [onResponse] is set then it will be called whenever a valid response
  /// is received. The returned [URLSessionResponseDisposition] will decide
  /// how the content of the response is processed. See
  /// [URLSession:dataTask:didReceiveResponse:completionHandler:](https://developer.apple.com/documentation/foundation/nsurlsessiondatadelegate/1410027-urlsession)
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
    URLRequest? Function(URLSession session, URLSessionTask task,
            HTTPURLResponse response, URLRequest newRequest)?
        onRedirect,
    URLSessionResponseDisposition Function(
            URLSession session, URLSessionTask task, URLResponse response)?
        onResponse,
    void Function(URLSession session, URLSessionTask task, Data error)? onData,
    void Function(URLSession session, URLSessionDownloadTask task, Uri uri)?
        onFinishedDownloading,
    void Function(URLSession session, URLSessionTask task, Error? error)?
        onComplete,
    void Function(
            URLSession session, URLSessionWebSocketTask task, String? protocol)?
        onWebSocketTaskOpened,
    void Function(URLSession session, URLSessionWebSocketTask task,
            int? closeCode, Data? reason)?
        onWebSocketTaskClosed,
  }) {
    // Avoid the complexity of simultaneous or out-of-order delegate callbacks
    // by only allowing callbacks to execute sequentially.
    // See https://developer.apple.com/forums/thread/47252
    // NOTE: this is likely to reduce throughput when there are multiple
    // requests in flight because each call to a delegate waits on a lock
    // that is unlocked by Dart code.
    final queue = ncb.NSOperationQueue.new1(linkedLibs)
      ..maxConcurrentOperationCount = 1
      ..name =
          'cupertino_http.NSURLSessionDelegateQueue'.toNSString(linkedLibs);

    return URLSession._(
        ncb.NSURLSession.sessionWithConfiguration_delegate_delegateQueue_(
            linkedLibs, config._nsObject, _delegate, queue),
        isBackground: config._isBackground,
        onRedirect: onRedirect,
        onResponse: onResponse,
        onData: onData,
        onFinishedDownloading: onFinishedDownloading,
        onComplete: onComplete,
        onWebSocketTaskOpened: onWebSocketTaskOpened,
        onWebSocketTaskClosed: onWebSocketTaskClosed);
  }

  /// A **copy** of the configuration for this session.
  ///
  /// See [NSURLSession.configuration](https://developer.apple.com/documentation/foundation/nsurlsession/1411477-configuration)
  URLSessionConfiguration get configuration => URLSessionConfiguration._(
      ncb.NSURLSessionConfiguration.castFrom(_nsObject.configuration!),
      isBackground: _isBackground);

  /// A description of the session that may be useful for debugging.
  ///
  /// See [NSURLSession.sessionDescription](https://developer.apple.com/documentation/foundation/nsurlsession/1408277-sessiondescription)
  String? get sessionDescription =>
      toStringOrNull(_nsObject.sessionDescription);
  set sessionDescription(String? value) =>
      _nsObject.sessionDescription = value?.toNSString(linkedLibs);

  /// Create a [URLSessionTask] that accesses a server URL.
  ///
  /// See [NSURLSession dataTaskWithRequest:](https://developer.apple.com/documentation/foundation/nsurlsession/1410592-datataskwithrequest)
  URLSessionTask dataTaskWithRequest(URLRequest request) {
    final task =
        URLSessionTask._(_nsObject.dataTaskWithRequest_(request._nsObject));
    _setupDelegation(_delegate, this, task,
        onComplete: _onComplete,
        onData: _onData,
        onFinishedDownloading: _onFinishedDownloading,
        onRedirect: _onRedirect,
        onResponse: _onResponse);
    return task;
  }

  /// Creates a [URLSessionTask] that accesses a server URL and calls
  /// [completion] when done.
  ///
  /// See [NSURLSession dataTaskWithRequest:completionHandler:](https://developer.apple.com/documentation/foundation/nsurlsession/1407613-datataskwithrequest)
  URLSessionTask dataTaskWithCompletionHandler(
      URLRequest request,
      void Function(Data? data, HTTPURLResponse? response, Error? error)
          completion) {
    // This method cannot be implemented by simply calling
    // `dataTaskWithRequest:completionHandler:` because the completion handler
    // will invoke the Dart callback on an arbitrary thread and Dart code
    // cannot be run that way
    // (see https://github.com/dart-lang/sdk/issues/37022).
    //
    // Instead, we use `dataTaskWithRequest:` and:
    // 1. create a port to receive information about the request.
    // 2. use a delegate to send information about the task to the port
    // 3. call the user-provided completion function when we receive the
    //    `CompletedMessage` message type.
    final task =
        URLSessionTask._(_nsObject.dataTaskWithRequest_(request._nsObject));

    HTTPURLResponse? finalResponse;
    MutableData? allData;

    _setupDelegation(_delegate, this, task, onRedirect: _onRedirect, onResponse:
        (URLSession session, URLSessionTask task, URLResponse response) {
      finalResponse =
          HTTPURLResponse._(ncb.NSHTTPURLResponse.castFrom(response._nsObject));
      return URLSessionResponseDisposition.urlSessionResponseAllow;
    }, onData: (URLSession session, URLSessionTask task, Data data) {
      allData ??= MutableData.empty();
      allData!.appendBytes(data.bytes);
    }, onComplete: (URLSession session, URLSessionTask task, Error? error) {
      completion(allData == null ? null : Data.fromData(allData!),
          finalResponse, error);
    });

    return URLSessionTask._(task._nsObject);
  }

  /// Creates a [URLSessionDownloadTask] that downloads the data from a server
  /// URL.
  ///
  /// Provide a `onFinishedDownloading` handler in the [URLSession] factory to
  /// receive notifications when the data has completed downloaded.
  ///
  /// See [NSURLSession downloadTaskWithRequest:](https://developer.apple.com/documentation/foundation/nsurlsession/1411481-downloadtaskwithrequest)
  URLSessionDownloadTask downloadTaskWithRequest(URLRequest request) {
    final task = URLSessionDownloadTask._(
        _nsObject.downloadTaskWithRequest_(request._nsObject));
    _setupDelegation(_delegate, this, task,
        onComplete: _onComplete,
        onData: _onData,
        onFinishedDownloading: _onFinishedDownloading,
        onRedirect: _onRedirect,
        onResponse: _onResponse);
    return task;
  }

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
          'WebSocket tasks are not supported in background sessions');
    }
    final task = URLSessionWebSocketTask._(
        _nsObject.webSocketTaskWithRequest_(request._nsObject));
    _setupDelegation(_delegate, this, task,
        onComplete: _onComplete,
        onData: _onData,
        onFinishedDownloading: _onFinishedDownloading,
        onRedirect: _onRedirect,
        onResponse: _onResponse,
        onWebSocketTaskOpened: _onWebSocketTaskOpened,
        onWebSocketTaskClosed: _onWebSocketTaskClosed);
    return task;
  }
}
