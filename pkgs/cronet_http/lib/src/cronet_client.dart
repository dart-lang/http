// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http/http.dart';
import 'package:http_profile/http_profile.dart';
import 'package:jni/jni.dart';

import 'jni/jni_bindings.dart' as jb;

final _digitRegex = RegExp(r'^\d+$');
const _bufferSize = 10 * 1024; // The size of the Cronet read buffer.

/// This class can be removed when `package:http` v2 is released.
class _StreamedResponseWithUrl extends StreamedResponse
    implements BaseResponseWithUrl {
  @override
  final Uri url;

  _StreamedResponseWithUrl(super.stream, super.statusCode,
      {required this.url,
      super.contentLength,
      super.request,
      super.headers,
      super.isRedirect,
      super.reasonPhrase});
}

/// An HTTP response from the Cronet network stack.
///
/// The response body is received asynchronously after the headers have been
/// received.
class CronetStreamedResponse extends _StreamedResponseWithUrl {
  final jb.UrlResponseInfo _responseInfo;

  /// The protocol (for example `'quic/1+spdy/3'`) negotiated with the server.
  ///
  /// It will be the empty string or `'unknown'` if no protocol was negotiated,
  /// the protocol is not known, or when using plain HTTP or HTTPS.
  String get negotiatedProtocol => _responseInfo
      .getNegotiatedProtocol()!
      .toDartString(releaseOriginal: true);

  /// The minimum count of bytes received from the network to process this
  /// request.
  ///
  /// This count may ignore certain overheads (for example IP and TCP/UDP
  /// framing, SSL handshake and framing, proxy handling). This count is taken
  /// prior to decompression (for example GZIP) and includes headers and data
  /// from all redirects. This value may change as more response data is
  /// received from the network.
  int get receivedByteCount => _responseInfo.getReceivedByteCount();

  /// Whether the response came from the cache.
  ///
  /// Is `true` for requests that were revalidated over the network before being
  /// retrieved from the cache
  bool get wasCached => _responseInfo.wasCached();

  CronetStreamedResponse._(super.stream, super.statusCode,
      {required jb.UrlResponseInfo responseInfo,
      required super.url,
      super.contentLength,
      super.request,
      super.headers,
      super.isRedirect,
      super.reasonPhrase})
      : _responseInfo = responseInfo;
}

/// The type of caching to use when making HTTP requests.
enum CacheMode {
  disabled,
  memory,
  diskNoHttp,
  disk,
}

/// An environment that can be used to make HTTP requests.
class CronetEngine {
  late final jb.CronetEngine _engine;
  bool _isClosed = false;

  CronetEngine._(this._engine);

  /// Construct a new [CronetEngine] with the given configuration.
  ///
  /// [cacheMode] controls the type of caching that should be used by the
  /// engine. If [cacheMode] is not [CacheMode.disabled] then [cacheMaxSize]
  /// must be set. If [cacheMode] is [CacheMode.disk] or [CacheMode.diskNoHttp]
  /// then [storagePath] must be set.
  ///
  /// [cacheMaxSize] is the maximum amount of data that should be cached, in
  /// bytes.
  ///
  /// [enableBrotli] controls whether
  /// [Brotli compression](https://www.rfc-editor.org/rfc/rfc7932) can be used.
  ///
  /// [enableHttp2] controls whether the HTTP/2 protocol can be used.
  ///
  /// [enablePublicKeyPinningBypassForLocalTrustAnchors] enables or disables
  /// public key pinning bypass for local trust anchors. Disabling the bypass
  /// for local trust anchors is highly discouraged since it may prohibit the
  /// app from communicating with the pinned hosts. E.g., a user may want to
  /// send all traffic through an SSL enabled proxy by changing the device
  /// proxy settings and adding the proxy certificate to the list of local
  /// trust anchor.
  ///
  /// [enableQuic] controls whether the [QUIC](https://www.chromium.org/quic/)
  /// protocol can be used.
  ///
  /// [storagePath] sets the path of an existing directory where HTTP data can
  /// be cached and where cookies can be stored. NOTE: a unique [storagePath]
  /// should be used per [CronetEngine].
  ///
  /// [userAgent] controls the `User-Agent` header.
  static CronetEngine build(
      {CacheMode? cacheMode,
      int? cacheMaxSize,
      bool? enableBrotli,
      bool? enableHttp2,
      bool? enablePublicKeyPinningBypassForLocalTrustAnchors,
      bool? enableQuic,
      String? storagePath,
      String? userAgent}) {
    final builder = jb.CronetEngine$Builder(
        JObject.fromReference(Jni.getCachedApplicationContext()));

    try {
      if (storagePath != null) {
        builder.setStoragePath(storagePath.toJString());
      }

      if (cacheMode == CacheMode.disabled) {
        builder.enableHttpCache(0, 0); // HTTP_CACHE_DISABLED, 0 bytes
      } else if (cacheMode != null && cacheMaxSize != null) {
        builder.enableHttpCache(cacheMode.index, cacheMaxSize);
      }

      if (enableBrotli != null) {
        builder.enableBrotli(enableBrotli);
      }

      if (enableHttp2 != null) {
        builder.enableHttp2(enableHttp2);
      }

      if (enablePublicKeyPinningBypassForLocalTrustAnchors != null) {
        builder.enablePublicKeyPinningBypassForLocalTrustAnchors(
            enablePublicKeyPinningBypassForLocalTrustAnchors);
      }

      if (enableQuic != null) {
        builder.enableQuic(enableQuic);
      }

      if (userAgent != null) {
        builder.setUserAgent(userAgent.toJString());
      }

      return CronetEngine._(builder.build()!);
    } on JniException catch (e) {
      // TODO: Decode this exception in a better way when
      // https://github.com/dart-lang/jnigen/issues/239 is fixed.
      if (e.message.contains('java.lang.IllegalArgumentException:')) {
        throw ArgumentError(
            e.message.split('java.lang.IllegalArgumentException:').last);
      }
      rethrow;
    }
  }

  void close() {
    if (!_isClosed) {
      _engine
        ..shutdown()
        ..release();
    }
    _isClosed = true;
  }
}

Map<String, String> _cronetToClientHeaders(
        JMap<JString?, JList<JString?>?> cronetHeaders) =>
    cronetHeaders.map((key, value) => MapEntry(
        key!.toDartString(releaseOriginal: true).toLowerCase(),
        value!.join(',')));

jb.UrlRequestCallbackProxy$UrlRequestCallbackInterface _urlRequestCallbacks(
    BaseRequest request,
    Completer<CronetStreamedResponse> responseCompleter,
    HttpClientRequestProfile? profile) {
  StreamController<List<int>>? responseStream;
  JByteBuffer? jByteBuffer;
  var numRedirects = 0;
  var done = false;

  // The order of callbacks generated by Cronet is documented here:
  // https://developer.android.com/guide/topics/connectivity/cronet/lifecycle
  return jb.UrlRequestCallbackProxy$UrlRequestCallbackInterface.implement(
      // All of the variables in the interface are non-nullable with the
      // exception of onFailed's UrlResponseInfo as specified in:
      // https://source.chromium.org/chromium/chromium/src/+/main:components/cronet/android/api/src/org/chromium/net/UrlRequest.java;l=232
      jb.$UrlRequestCallbackProxy$UrlRequestCallbackInterface(
    onResponseStarted: (urlRequest, responseInfo) {
      responseStream = StreamController(onCancel: () {
        // The user did `response.stream.cancel()`. We can just pretend that
        // the response completed normally.
        if (done) return;
        done = true;
        urlRequest!.cancel();
        responseStream!.sink.close();
        jByteBuffer?.release();
        profile?.responseData.close();
      });
      final responseHeaders =
          _cronetToClientHeaders(responseInfo!.getAllHeaders()!);
      int? contentLength;

      switch (responseHeaders['content-length']) {
        case final contentLengthHeader?
            when !_digitRegex.hasMatch(contentLengthHeader):
          responseCompleter.completeError(ClientException(
            'Invalid content-length header [$contentLengthHeader].',
            request.url,
          ));
          urlRequest?.cancel();
          return;
        case final contentLengthHeader?:
          contentLength = int.parse(contentLengthHeader);
      }
      responseCompleter.complete(CronetStreamedResponse._(
        responseStream!.stream,
        responseInfo.getHttpStatusCode(),
        responseInfo: responseInfo,
        url: Uri.parse(
            responseInfo.getUrl()!.toDartString(releaseOriginal: true)),
        contentLength: contentLength,
        reasonPhrase: responseInfo
            .getHttpStatusText()!
            .toDartString(releaseOriginal: true),
        request: request,
        isRedirect: false,
        headers: responseHeaders,
      ));

      profile?.requestData.close();
      profile?.responseData
        ?..contentLength = contentLength
        ..headersCommaValues = responseHeaders
        ..isRedirect = false
        ..reasonPhrase = responseInfo
            .getHttpStatusText()!
            .toDartString(releaseOriginal: true)
        ..startTime = DateTime.now()
        ..statusCode = responseInfo.getHttpStatusCode();
      jByteBuffer = JByteBuffer.allocateDirect(_bufferSize);
      urlRequest?.read(jByteBuffer!);
    },
    onRedirectReceived: (urlRequest, responseInfo, newLocationUrl) {
      if (done) return;
      final responseHeaders =
          _cronetToClientHeaders(responseInfo!.getAllHeaders()!);

      if (!request.followRedirects) {
        urlRequest!.cancel();
        responseCompleter.complete(CronetStreamedResponse._(
            const Stream.empty(), // Cronet provides no body for redirects.
            responseInfo.getHttpStatusCode(),
            responseInfo: responseInfo,
            url: Uri.parse(
                responseInfo.getUrl()!.toDartString(releaseOriginal: true)),
            contentLength: 0,
            reasonPhrase: responseInfo
                .getHttpStatusText()!
                .toDartString(releaseOriginal: true),
            request: request,
            isRedirect: true,
            headers: _cronetToClientHeaders(responseInfo.getAllHeaders()!)));

        profile?.responseData
          ?..headersCommaValues = responseHeaders
          ..isRedirect = true
          ..reasonPhrase = responseInfo
              .getHttpStatusText()!
              .toDartString(releaseOriginal: true)
          ..startTime = DateTime.now()
          ..statusCode = responseInfo.getHttpStatusCode();

        return;
      }
      ++numRedirects;
      if (numRedirects <= request.maxRedirects) {
        profile?.responseData.addRedirect(HttpProfileRedirectData(
            statusCode: responseInfo.getHttpStatusCode(),
            // This method is not correct for status codes 303 to 307. Cronet
            // does not seem to have a way to get the method so we'd have to
            // calculate it according to the rules in RFC-7231.
            method: 'GET',
            location: newLocationUrl!.toDartString(releaseOriginal: true)));
        urlRequest!.followRedirect();
      } else {
        urlRequest!.cancel();
        responseCompleter.completeError(
            ClientException('Redirect limit exceeded', request.url));
      }
    },
    onReadCompleted: (urlRequest, responseInfo, byteBuffer) {
      if (done) return;
      byteBuffer!.flip();
      final data = jByteBuffer!.asUint8List().sublist(0, byteBuffer.remaining);
      responseStream!.add(data);
      profile?.responseData.bodySink.add(data);

      byteBuffer.clear();
      urlRequest!.read(byteBuffer);
    },
    onSucceeded: (urlRequest, responseInfo) {
      if (done) return;
      done = true;
      responseStream!.sink.close();
      jByteBuffer?.release();
      profile?.responseData.close();
    },
    onFailed: (urlRequest, responseInfo /* can be null */, cronetException) {
      if (done) return;
      done = true;
      final error = ClientException(
          'Cronet exception: ${cronetException.toString()}', request.url);
      if (responseStream == null) {
        responseCompleter.completeError(error);
      } else {
        responseStream!.addError(error);
        responseStream!.close();
      }

      if (profile != null) {
        if (profile.requestData.endTime == null) {
          profile.requestData.closeWithError(error.toString());
        } else {
          profile.responseData.closeWithError(error.toString());
        }
      }
      jByteBuffer?.release();
    },
  ));
}

/// A HTTP [Client] based on the
/// [Cronet](https://developer.android.com/guide/topics/connectivity/cronet)
/// network stack.
class CronetClient extends BaseClient {
  static final _executor = jb.Executors.newCachedThreadPool();
  CronetEngine? _engine;
  bool _isClosed = false;

  /// Indicates that [CronetClient] is responsible for closing [_engine].
  final bool _closeEngine;

  CronetClient._(this._engine, this._closeEngine);

  /// A [CronetClient] that will be initialized with a new [CronetEngine].
  factory CronetClient.defaultCronetEngine() => CronetClient._(null, true);

  /// A [CronetClient] configured with a [CronetEngine].
  ///
  /// If [closeEngine] is `true`, then [engine] will be closed when [close] is
  /// called on this [CronetClient]. This can simplify lifetime management if
  /// [engine] is only used in one [CronetClient].
  factory CronetClient.fromCronetEngine(CronetEngine engine,
          {bool closeEngine = false}) =>
      CronetClient._(engine, closeEngine);

  /// A [CronetClient] configured with a [Future] containing a [CronetEngine].
  ///
  /// This can be useful in circumstances where a non-Future [CronetClient] is
  /// required but you want to configure the [CronetClient] with a custom
  /// [CronetEngine]. For example:
  /// ```
  /// void main() {
  ///   Client clientFactory() {
  ///     final engine = CronetEngine.build(
  ///         cacheMode: CacheMode.memory, userAgent: 'Book Agent');
  ///     return CronetClient.fromCronetEngineFuture(engine);
  ///   }
  ///
  ///   runWithClient(() => runApp(const BookSearchApp()), clientFactory);
  /// }
  /// ```
  @override
  void close() {
    if (!_isClosed && _closeEngine) {
      _engine?.close();
    }
    _isClosed = true;
  }

  HttpClientRequestProfile? _createProfile(BaseRequest request) =>
      HttpClientRequestProfile.profile(
          requestStartTime: DateTime.now(),
          requestMethod: request.method,
          requestUri: request.url.toString());

  /// Sends an HTTP request and asynchronously returns the response.
  @override
  Future<CronetStreamedResponse> send(BaseRequest request) async {
    if (_isClosed) {
      throw ClientException(
          'HTTP request failed. Client is already closed.', request.url);
    }

    final engine = _engine ?? CronetEngine.build();
    _engine = engine;

    if (engine._isClosed) {
      throw ClientException(
          'HTTP request failed. CronetEngine is already closed.', request.url);
    }

    final profile = _createProfile(request);
    profile?.connectionInfo = {
      'package': 'package:cronet_http',
      'client': 'CronetHttp',
    };
    profile?.requestData
      ?..contentLength = request.contentLength
      ..followRedirects = request.followRedirects
      ..headersCommaValues = request.headers
      ..maxRedirects = request.maxRedirects;
    if (profile != null && request.contentLength != null) {
      profile.requestData.headersListValues = {
        'Content-Length': ['${request.contentLength}'],
        ...profile.requestData.headers!
      };
    }

    final stream = request.finalize();
    final body = await stream.toBytes();
    profile?.requestData.bodySink.add(body);

    final responseCompleter = Completer<CronetStreamedResponse>();

    final builder = engine._engine.newUrlRequestBuilder(
      request.url.toString().toJString(),
      jb.UrlRequestCallbackProxy(
          _urlRequestCallbacks(request, responseCompleter, profile)),
      _executor,
    )!
      ..setHttpMethod(request.method.toJString());

    var headers = request.headers;
    if (body.isNotEmpty &&
        !headers.keys.any((h) => h.toLowerCase() == 'content-type')) {
      // Cronet requires that requests containing upload data set a
      // 'Content-Type' header.
      headers = {...headers, 'content-type': 'application/octet-stream'};
    }
    headers.forEach((k, v) => builder.addHeader(k.toJString(), v.toJString()));

    if (body.isNotEmpty) {
      final JByteBuffer data;
      try {
        data = body.toJByteBuffer();
      } on JniException catch (e) {
        // There are no unit tests for this code. You can verify this behavior
        // manually by incrementally increasing the amount of body data in
        // `CronetClient.post` until you get this exception.
        if (e.message.contains('java.lang.OutOfMemoryError:')) {
          throw ClientException(
              'Not enough memory for request body: ${e.message}', request.url);
        }
        rethrow;
      }

      builder.setUploadDataProvider(
          jb.UploadDataProviders.create$2(data), _executor);
    }
    builder.build()!.start();
    return responseCompleter.future;
  }
}

/// A test-only class that makes the [HttpClientRequestProfile] data available.
class CronetClientWithProfile extends CronetClient {
  HttpClientRequestProfile? profile;

  @override
  HttpClientRequestProfile? _createProfile(BaseRequest request) =>
      profile = super._createProfile(request);

  CronetClientWithProfile._(super._engine, super._closeEngine) : super._();

  factory CronetClientWithProfile.defaultCronetEngine() =>
      CronetClientWithProfile._(null, true);
}
