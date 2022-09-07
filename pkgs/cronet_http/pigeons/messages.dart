// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Defines messages exchanged between the cronet_http native and Dart code.

import 'package:pigeon/pigeon.dart';

enum CacheMode {
  disabled,
  memory,
  diskNoHttp,
  disk,
}

/// An event message sent when the response headers are received.
///
/// If [StartRequest.followRedirects] was false, then the first response,
/// regardless of whether it is a redirect or not, will be returned. Otherwise,
/// this is the response after all redirects have been followed.
///
/// See
/// [UrlRequest.Callback.onResponseStarted](https://developer.android.com/guide/topics/connectivity/cronet/reference/org/chromium/net/UrlRequest.Callback.html#public-abstract-void-onresponsestarted-urlrequest-request,-urlresponseinfo-info)
class ResponseStarted {
  Map<String?, List<String?>?> headers;
  int statusCode;
  String statusText;
  bool isRedirect;
}

/// An event message sent when part of the response body has been received.
///
/// See
/// [UrlRequest.Callback.onReadCompleted](https://developer.android.com/guide/topics/connectivity/cronet/reference/org/chromium/net/UrlRequest.Callback.html#public-abstract-void-onreadcompleted-urlrequest-request,-urlresponseinfo-info,-bytebuffer-bytebuffer)
class ReadCompleted {
  Uint8List data;
}

enum ExceptionType {
  illegalArgumentException,
  otherException,
}

enum EventMessageType { responseStarted, readCompleted, tooManyRedirects }

/// Encapsulates a message sent from Cronet to the Dart client.
class EventMessage {
  EventMessageType type;

  // Set if [type] == responseStarted;
  ResponseStarted? responseStarted;

  // Set if [type] == readCompleted;
  ReadCompleted? readCompleted;
}

class CreateEngineRequest {
  CacheMode? cacheMode;
  int? cacheMaxSize;
  bool? enableBrotli;
  bool? enableHttp2;
  bool? enablePublicKeyPinningBypassForLocalTrustAnchors;
  bool? enableQuic;
  String? storagePath;
  String? userAgent;
}

class CreateEngineResponse {
  String? engineId;
  String? errorString;
  ExceptionType? errorType;
}

class StartRequest {
  String engineId;
  String url;
  String method;
  Map<String?, String?> headers;
  Uint8List body;
  int maxRedirects;
  bool followRedirects;
}

class StartResponse {
  // The channel that the caller should listen to for events related to the
  // HTTP request.
  String eventChannel;
}

@HostApi()
abstract class HttpApi {
  // Create a new CronetEngine with the given properties and returns it's id.
  CreateEngineResponse createEngine(CreateEngineRequest request);

  // Free the resources associated with the CronetEngine.
  void freeEngine(String engineId);

  /// Starts an HTTP request using an existing CronetEngine and returns a
  /// channel where future results will be streamed.
  StartResponse start(StartRequest request);

  // Pigeon does not generate code for classes that are not used in an API.
  // So create a dummy method that includes classes that will be used for
  // other purposes e.g. are sent over an `EventChannel`.
  void dummy(EventMessage message);
}
