// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A macOS/iOS Flutter plugin that provides access to the
/// [Foundation URL Loading System](https://developer.apple.com/documentation/foundation/url_loading_system).
///
/// For example:
/// ```
/// void main() {
///   final url = Uri.https('www.example.com', '/');
///   final session = URLSession.sharedSession();
///   final task = session.dataTaskWithCompletionHandler(URLRequest.fromUrl(url),
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

import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'src/native_cupertino_bindings.dart' as ncb;
import 'src/utils.dart';

abstract class _ObjectHolder<T extends ncb.NSObject> {
  final T _nsObject;

  _ObjectHolder(this._nsObject);
}

/// Settings for controlling whether cookies will be accepted.
///
/// See [HTTPCookieAcceptPolicy](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1408933-httpcookieacceptpolicy).
enum HTTPCookieAcceptPolicy {
  httpCookieAcceptPolicyAlways,
  httpCookieAcceptPolicyNever,
  httpCookieAcceptPolicyOnlyFromMainDocumentDomain,
}

// Controls how [URLSessionTask] execute will proceed after the response is
// received.
//
// See [NSURLSessionResponseDisposition](https://developer.apple.com/documentation/foundation/nsurlsessionresponsedisposition).
enum URLSessionResponseDisposition {
  urlSessionResponseCancel,
  urlSessionResponseAllow,
  urlSessionResponseBecomeDownload,
  urlSessionResponseBecomeStream
}

/// Information about a failure.
///
/// See [NSError](https://developer.apple.com/documentation/foundation/nserror)
class Error extends _ObjectHolder<ncb.NSError> {
  Error._(ncb.NSError c) : super(c);

  /// The numeric code for the error e.g. -1003 (kCFURLErrorCannotFindHost).
  ///
  /// The interpretation of this code will depend on the domain of the error
  /// which, for URL loading, will usually be
  /// [`kCFErrorDomainCFNetwork`](https://developer.apple.com/documentation/cfnetwork/kcferrordomaincfnetwork).
  ///
  /// See [NSError.code](https://developer.apple.com/documentation/foundation/nserror/1409165-code)
  int get code => this._nsObject.code;

  // TODO(https://github.com/dart-lang/ffigen/issues/386): expose
  // `NSError.domain` when correct type aliases are available.

  /// A description of the error in the current locale e.g.
  /// 'A server with the specified hostname could not be found.'
  ///
  /// See [NSError.locaizedDescription](https://developer.apple.com/documentation/foundation/nserror/1414418-localizeddescription)
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
  String toString() {
    return "[Error "
        "code=$code "
        "localizedDescription=$localizedDescription "
        "localizedFailureReason=$localizedFailureReason "
        "localizedRecoverySuggestion=$localizedRecoverySuggestion "
        "]";
  }
}

/// Controls the behavior of a URLSession.
///
/// See [NSURLSessionConfiguration](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration)
class URLSessionConfiguration
    extends _ObjectHolder<ncb.NSURLSessionConfiguration> {
  URLSessionConfiguration._(ncb.NSURLSessionConfiguration c) : super(c);

  /// A configuration suitable for performing HTTP uploads and downloads in
  /// the background.
  ///
  /// See [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1407496-backgroundsessionconfigurationwi)
  factory URLSessionConfiguration.backgroundSession(String identifier) {
    return URLSessionConfiguration._(ncb.NSURLSessionConfiguration
        .backgroundSessionConfigurationWithIdentifier_(
            linkedLibs, identifier.toNSString(linkedLibs)));
  }

  /// A configuration that uses caching and saves cookies and credentials.
  ///
  /// See [NSURLSessionConfiguration defaultSessionConfiguration](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1411560-defaultsessionconfiguration)
  factory URLSessionConfiguration.defaultSessionConfiguration() {
    return URLSessionConfiguration._(ncb.NSURLSessionConfiguration.castFrom(
        ncb.NSURLSessionConfiguration.getDefaultSessionConfiguration(
            linkedLibs)!));
  }

  /// A configuration that uses caching and saves cookies and credentials.
  ///
  /// See [NSURLSessionConfiguration ephemeralSessionConfiguration](https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1410529-ephemeralsessionconfiguration)
  factory URLSessionConfiguration.ephemeralSessionConfiguration() {
    return URLSessionConfiguration._(ncb.NSURLSessionConfiguration.castFrom(
        ncb.NSURLSessionConfiguration.getEphemeralSessionConfiguration(
            linkedLibs)!));
  }

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
  Duration get timeoutIntervalForRequest {
    return Duration(
        microseconds: (_nsObject.timeoutIntervalForRequest *
                Duration.microsecondsPerSecond)
            .round());
  }

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
  String toString() {
    return "[URLSessionConfiguration "
        "allowsCellularAccess=$allowsCellularAccess "
        "allowsConstrainedNetworkAccess=$allowsConstrainedNetworkAccess "
        "allowsExpensiveNetworkAccess=$allowsExpensiveNetworkAccess "
        "discretionary=$discretionary "
        "httpCookieAcceptPolicy=$httpCookieAcceptPolicy "
        "httpShouldSetCookies=$httpShouldSetCookies "
        "httpShouldUsePipelining=$httpShouldUsePipelining "
        "sessionSendsLaunchEvents=$sessionSendsLaunchEvents "
        "shouldUseExtendedBackgroundIdleMode=$shouldUseExtendedBackgroundIdleMode "
        "timeoutIntervalForRequest=$timeoutIntervalForRequest "
        "waitsForConnectivity=$waitsForConnectivity"
        "]";
  }
}

/// A container for byte data.
///
/// See [NSData](https://developer.apple.com/documentation/foundation/nsdata)
class Data extends _ObjectHolder<ncb.NSData> {
  Data._(ncb.NSData c) : super(c);

  // A new [Data] from an existing one.
  //
  // See [NSData dataWithData:](https://developer.apple.com/documentation/foundation/nsdata/1547230-datawithdata)
  factory Data.fromData(Data d) {
    return Data._(ncb.NSData.dataWithData_(linkedLibs, d._nsObject));
  }

  /// A new [Data] object containing the given bytes.
  factory Data.fromUint8List(Uint8List l) {
    final f = calloc<Uint8>(l.length);
    try {
      f.asTypedList(l.length).setAll(0, l);

      final data =
          ncb.NSData.dataWithBytes_length_(linkedLibs, f.cast(), l.length);
      return Data._(data);
    } finally {
      calloc.free(f);
    }
  }

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
    return "[Data " + "length=$length " + "bytes=0x$b..." + "]";
  }
}

/// A container for byte data.
///
/// See [NSMutableData](https://developer.apple.com/documentation/foundation/nsmutabledata)
class MutableData extends Data {
  final ncb.NSMutableData _mutableData;

  MutableData._(ncb.NSMutableData c)
      : _mutableData = c,
        super._(c);

  /// A new empty [MutableData].
  factory MutableData.empty() {
    return MutableData._(ncb.NSMutableData.dataWithCapacity_(linkedLibs, 0));
  }

  /// Appends the given data.
  ///
  /// See [NSMutableData appendBytes:length:](https://developer.apple.com/documentation/foundation/nsmutabledata/1407704-appendbytes)
  void appendBytes(Uint8List l) {
    final f = calloc<Uint8>(l.length);
    try {
      f.asTypedList(l.length).setAll(0, l);

      _mutableData.appendBytes_length_(f.cast(), l.length);
    } finally {
      calloc.free(f);
    }
  }

  String toString() {
    final subrange =
        length == 0 ? Uint8List(0) : bytes.sublist(0, min(length - 1, 20));
    final b = subrange.map((e) => e.toRadixString(16)).join();
    return "[MutableData " + "length=$length " + "bytes=0x$b..." + "]";
  }
}

/// The response associated with loading an URL.
///
/// See [NSURLResponse](https://developer.apple.com/documentation/foundation/nsurlresponse)
class URLResponse extends _ObjectHolder<ncb.NSURLResponse> {
  URLResponse._(ncb.NSURLResponse c) : super(c);

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
  String toString() {
    return "[URLResponse " +
        "mimeType=$mimeType " +
        "expectedContentLength=$expectedContentLength" +
        "]";
  }
}

/// The response associated with loading a HTTP URL.
///
/// See [NSHTTPURLResponse](https://developer.apple.com/documentation/foundation/nshttpurlresponse)
class HTTPURLResponse extends URLResponse {
  final ncb.NSHTTPURLResponse _httpUrlResponse;

  HTTPURLResponse._(ncb.NSHTTPURLResponse c)
      : _httpUrlResponse = c,
        super._(c);

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
    return (stringDictToMap(headers));
  }

  @override
  String toString() {
    return "[HTTPURLResponse " +
        "statusCode=$statusCode " +
        "mimeType=$mimeType " +
        "expectedContentLength=$expectedContentLength" +
        "]";
  }
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

/// A task associated with downloading a URI.
///
/// See [NSURLSessionTask](https://developer.apple.com/documentation/foundation/nsurlsessiontask)
class URLSessionTask extends _ObjectHolder<ncb.NSURLSessionTask> {
  URLSessionTask._(ncb.NSURLSessionTask c) : super(c);

  /// Cancels the task.
  ///
  /// See [NSURLSessionTask cancel](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1411591-cancel)
  void cancel() {
    this._nsObject.cancel();
  }

  /// Resumes a suspended task (new tasks start as suspended).
  ///
  /// See [NSURLSessionTask resume](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1411121-resume)
  void resume() {
    this._nsObject.resume();
  }

  /// Suspends a task (prevents it from transfering data).
  ///
  /// See [NSURLSessionTask suspend](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1411565-suspend)
  void suspend() {
    this._nsObject.suspend();
  }

  /// The current state of the task.
  ///
  /// See [NSURLSessionTask.state](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1409888-state)
  URLSessionTaskState get state => URLSessionTaskState.values[_nsObject.state];

  // A unique ID for the [URLSessionTask] in a [URLSession].
  //
  // See [NSURLSessionTask.taskIdentifier](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1411231-taskidentifier)
  int get taskIdentifider => _nsObject.taskIdentifier;

  /// The server response to the request associated with this task.
  ///
  /// See [NSURLSessionTask.response](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1410586-response)
  URLResponse? get response {
    if (_nsObject.response == null) {
      return null;
    } else {
      // TODO(https://github.com/dart-lang/ffigen/issues/373): remove cast
      // when precise type signatures are generated.
      return URLResponse._exactURLResponseType(
          ncb.NSURLResponse.castFrom(_nsObject.response!));
    }
  }

  /// The number of content bytes that have been received from the server.
  ///
  /// [NSURLSessionTask.countOfBytesReceived](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1411581-countofbytesreceived)
  int get countOfBytesReceived => _nsObject.countOfBytesReceived;

  /// The number of content bytes that are expected to be received from the server.
  ///
  /// [NSURLSessionTask.countOfBytesReceived](https://developer.apple.com/documentation/foundation/nsurlsessiontask/1410663-countofbytesexpectedtoreceive)
  int get countOfBytesExpectedToReceive =>
      _nsObject.countOfBytesExpectedToReceive;

  @override
  String toString() {
    return "[URLSessionTask "
        "taskIdentifider=$taskIdentifider "
        "countOfBytesExpectedToReceive=$countOfBytesExpectedToReceive "
        "countOfBytesReceived=$countOfBytesReceived "
        "state=$state"
        "]";
  }
}

/// A request to load a URL.
///
/// See [NSURLRequest](https://developer.apple.com/documentation/foundation/nsurlrequest)
class URLRequest extends _ObjectHolder<ncb.NSURLRequest> {
  URLRequest._(ncb.NSURLRequest c) : super(c);

  /// Creates a request for a URL.
  ///
  /// See [NSURLRequest.requestWithURL:](https://developer.apple.com/documentation/foundation/nsurlrequest/1528603-requestwithurl)
  factory URLRequest.fromUrl(Uri uri) {
    // TODO(https://github.com/dart-lang/ffigen/issues/373): remove NSObject
    // cast when precise type signatures are generated.
    final url = ncb.NSURL.URLWithString_(linkedLibs,
        ncb.NSObject.castFrom(uri.toString().toNSString(linkedLibs)));
    return URLRequest._(ncb.NSURLRequest.requestWithURL_(linkedLibs, url));
  }

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
  String get httpMethod {
    return toStringOrNull(_nsObject.HTTPMethod)!;
  }

  /// The requested URL.
  ///
  /// See [URLRequest.URL](https://developer.apple.com/documentation/foundation/nsurlrequest/1408996-url)
  Uri? get url {
    final nsUrl = _nsObject.URL;
    if (nsUrl == null) {
      return null;
    }
    // TODO(https://github.com/dart-lang/ffigen/issues/373): remove NSObject
    // cast when precise type signatures are generated.
    return Uri.parse(toStringOrNull(ncb.NSURL.castFrom(nsUrl).absoluteString)!);
  }

  @override
  String toString() {
    return "[URLRequest "
        "allHttpHeaderFields=$allHttpHeaderFields "
        "httpBody=$httpBody "
        "httpMethod=$httpMethod "
        "url=$url "
        "]";
  }
}

/// A mutable request to load a URL.
///
/// See [NSMutableURLRequest](https://developer.apple.com/documentation/foundation/nsmutableurlrequest)
class MutableURLRequest extends URLRequest {
  final ncb.NSMutableURLRequest _mutableUrlRequest;

  MutableURLRequest._(ncb.NSMutableURLRequest c)
      : _mutableUrlRequest = c,
        super._(c);

  /// Creates a request for a URL.
  ///
  /// See [NSMutableURLRequest.requestWithURL:](https://developer.apple.com/documentation/foundation/nsmutableurlrequest/1414617-allhttpheaderfields)
  factory MutableURLRequest.fromUrl(Uri uri) {
    final url = ncb.NSURL
        .URLWithString_(linkedLibs, uri.toString().toNSString(linkedLibs));
    return MutableURLRequest._(
        ncb.NSMutableURLRequest.requestWithURL_(linkedLibs, url));
  }

  set httpBody(Data? data) {
    _mutableUrlRequest.HTTPBody = data?._nsObject;
  }

  set httpMethod(String method) {
    _mutableUrlRequest.HTTPMethod = method.toNSString(linkedLibs);
  }

  /// Set the value of a header field.
  ///
  /// See [NSMutableURLRequest setValue:forHTTPHeaderField:](https://developer.apple.com/documentation/foundation/nsmutableurlrequest/1408793-setvalue)
  void setValueForHttpHeaderField(String value, String field) {
    _mutableUrlRequest.setValue_forHTTPHeaderField_(
        field.toNSString(linkedLibs), value.toNSString(linkedLibs));
  }

  @override
  String toString() {
    return "[MutableURLRequest "
        "allHttpHeaderFields=$allHttpHeaderFields "
        "httpBody=$httpBody "
        "httpMethod=$httpMethod "
        "]";
  }
}

/// Setup delegation for the given [task] to the given methods.
///
/// Specifically, this causes the Objective-C-implemented delegate installed
/// with
/// [sessionWithConfiguration:delegate:delegateQueue:](https://developer.apple.com/documentation/foundation/nsurlsession/1411597-sessionwithconfiguration)
/// to send a [ncb.CUPHTTPForwardedDelegate] object to a send port, which is
/// then processed by [_setupDelegation] and forwarded to the given methods.
void _setupDelegation(
    ncb.CUPHTTPClientDelegate delegate, URLSession session, URLSessionTask task,
    {URLRequest? Function(URLSession session, URLSessionTask task,
            HTTPURLResponse response, URLRequest newRequest)?
        onRedirect,
    URLSessionResponseDisposition Function(
            URLSession session, URLSessionTask task, URLResponse response)?
        onResponse,
    void Function(URLSession session, URLSessionTask task, Data error)? onData,
    void Function(URLSession session, URLSessionTask task, Error? error)?
        onComplete}) {
  final responsePort = ReceivePort();
  responsePort.listen((message) {
    final messageType = message[0];
    final dp = Pointer<ncb.ObjCObject>.fromAddress(message[1]);

    final forwardedDelegate =
        ncb.CUPHTTPForwardedDelegate.castFromPointer(helperLibs, dp,
            // `CUPHTTPForwardedDelegate` was retained in the delegate so it
            // only needs to be released.
            retain: false,
            release: true);

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
          // TODO(https://github.com/dart-lang/ffigen/issues/373): remove cast
          // when precise type signatures are generated.
          final response = URLResponse._exactURLResponseType(
              ncb.NSURLResponse.castFrom(forwardedResponse.response!));

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
  static late ncb.CUPHTTPClientDelegate _delegate =
      ncb.CUPHTTPClientDelegate.new1(helperLibs);

  URLRequest? Function(URLSession session, URLSessionTask task,
      HTTPURLResponse response, URLRequest newRequest)? _onRedirect;
  URLSessionResponseDisposition Function(
          URLSession session, URLSessionTask task, URLResponse response)?
      _onResponse;
  void Function(URLSession session, URLSessionTask task, Data error)? _onData;
  void Function(URLSession session, URLSessionTask task, Error? error)?
      _onComplete;

  URLSession._(ncb.NSURLSession c,
      {URLRequest? Function(URLSession session, URLSessionTask task,
              HTTPURLResponse response, URLRequest newRequest)?
          onRedirect,
      URLSessionResponseDisposition Function(
              URLSession session, URLSessionTask task, URLResponse response)?
          onResponse,
      void Function(URLSession session, URLSessionTask task, Data error)?
          onData,
      void Function(URLSession session, URLSessionTask task, Error? error)?
          onComplete})
      : _onRedirect = onRedirect,
        _onResponse = onResponse,
        _onData = onData,
        _onComplete = onComplete,
        super(c);

  /// A client with reasonable default behavior.
  ///
  /// See [NSURLSession.sharedSession](https://developer.apple.com/documentation/foundation/nsurlsession/1409000-sharedsession)
  factory URLSession.sharedSession() {
    return URLSession.sessionWithConfiguration(
        URLSessionConfiguration.defaultSessionConfiguration());
  }

  /// A client with a given configuration.
  ///
  /// If [onRedirect] is set then it will be called whenever a HTTP
  /// request returns a redirect response (e.g. 302). The `response` parameter
  /// contains the response from the server. The `newRequest` parameter contains
  /// a follow-up request that would honor the server's redirect. If the return
  /// value of this function is `null` then the redirect will not occur.
  /// Otherwise, the returned [URLRequest] (usually `newRequest`) will be
  /// executed. See
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
  /// If [onComplete] is set then it will be called when a task completes. If
  /// `error` is `null` then the request completed successfully. See
  /// [URLSession:task:didCompleteWithError:](https://developer.apple.com/documentation/foundation/nsurlsessiontaskdelegate/1411610-urlsession)
  ///
  /// See [sessionWithConfiguration:delegate:delegateQueue:](https://developer.apple.com/documentation/foundation/nsurlsession/1411597-sessionwithconfiguration)
  factory URLSession.sessionWithConfiguration(URLSessionConfiguration config,
      {URLRequest? Function(URLSession session, URLSessionTask task,
              HTTPURLResponse response, URLRequest newRequest)?
          onRedirect,
      URLSessionResponseDisposition Function(
              URLSession session, URLSessionTask task, URLResponse response)?
          onResponse,
      void Function(URLSession session, URLSessionTask task, Data error)?
          onData,
      void Function(URLSession session, URLSessionTask task, Error? error)?
          onComplete}) {
    return URLSession._(
        ncb.NSURLSession.sessionWithConfiguration_delegate_delegateQueue_(
            linkedLibs, config._nsObject, _delegate, null),
        onRedirect: onRedirect,
        onResponse: onResponse,
        onData: onData,
        onComplete: onComplete);
  }

  // A **copy** of the configuration for this sesion.
  //
  // See [NSURLSession.configuration](https://developer.apple.com/documentation/foundation/nsurlsession/1411477-configuration)
  URLSessionConfiguration get configuration {
    return URLSessionConfiguration._(
        ncb.NSURLSessionConfiguration.castFrom(_nsObject.configuration!));
  }

  // Create a [URLSessionTask] that accesses a server URL.
  //
  // See [NSURLSession dataTaskWithRequest:](https://developer.apple.com/documentation/foundation/nsurlsession/1410592-datataskwithrequest)
  URLSessionTask dataTaskWithRequest(URLRequest request) {
    final task =
        URLSessionTask._(_nsObject.dataTaskWithRequest_(request._nsObject));
    _setupDelegation(_delegate, this, task,
        onComplete: _onComplete,
        onData: _onData,
        onRedirect: _onRedirect,
        onResponse: _onResponse);
    return task;
  }

  /// Creates a [URLSessionTask] accesses a server URL and calls [completion]
  /// when done.
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
      if (allData == null) {
        allData = MutableData.empty();
      }
      allData!.appendBytes(data.bytes);
    }, onComplete: (URLSession session, URLSessionTask task, Error? error) {
      completion(allData == null ? null : Data.fromData(allData!),
          finalResponse, error);
    });

    return URLSessionTask._(task._nsObject);
  }
}
