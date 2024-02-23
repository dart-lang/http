// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// An Android Flutter plugin that provides access to the
/// [Cronet](https://developer.android.com/guide/topics/connectivity/cronet/reference/org/chromium/net/package-summary)
/// HTTP client.
///
/// The platform interface must be initialized before using this plugin e.g. by
/// calling
/// [`WidgetsFlutterBinding.ensureInitialized`](https://api.flutter.dev/flutter/widgets/WidgetsFlutterBinding/ensureInitialized.html)
/// or
/// [`runApp`](https://api.flutter.dev/flutter/widgets/runApp.html).
library;

import 'dart:async';

import 'package:http/http.dart';
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
    final builder = jb.CronetEngine_Builder(
        JObject.fromRef(Jni.getCachedApplicationContext()));

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

      return CronetEngine._(builder.build());
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
        JMap<JString, JList<JString>> cronetHeaders) =>
    cronetHeaders.map((key, value) => MapEntry(
        key.toDartString(releaseOriginal: true).toLowerCase(),
        value.join(',')));

jb.UrlRequestCallbackProxy_UrlRequestCallbackInterface _urlRequestCallbacks(
    BaseRequest request, Completer<StreamedResponse> responseCompleter) {
  StreamController<List<int>>? responseStream;
  JByteBuffer? jByteBuffer;
  var numRedirects = 0;

  // The order of callbacks generated by Cronet is documented here:
  // https://developer.android.com/guide/topics/connectivity/cronet/lifecycle
  return jb.UrlRequestCallbackProxy_UrlRequestCallbackInterface.implement(
      jb.$UrlRequestCallbackProxy_UrlRequestCallbackInterfaceImpl(
    onResponseStarted: (urlRequest, responseInfo) {
      responseStream = StreamController();
      final responseHeaders =
          _cronetToClientHeaders(responseInfo.getAllHeaders());
      int? contentLength;

      switch (responseHeaders['content-length']) {
        case final contentLengthHeader?
            when !_digitRegex.hasMatch(contentLengthHeader):
          responseCompleter.completeError(ClientException(
            'Invalid content-length header [$contentLengthHeader].',
            request.url,
          ));
          urlRequest.cancel();
          return;
        case final contentLengthHeader?:
          contentLength = int.parse(contentLengthHeader);
      }
      responseCompleter.complete(_StreamedResponseWithUrl(
        responseStream!.stream,
        responseInfo.getHttpStatusCode(),
        url: Uri.parse(
            responseInfo.getUrl().toDartString(releaseOriginal: true)),
        contentLength: contentLength,
        reasonPhrase: responseInfo
            .getHttpStatusText()
            .toDartString(releaseOriginal: true),
        request: request,
        isRedirect: false,
        headers: responseHeaders,
      ));

      jByteBuffer = JByteBuffer.allocateDirect(_bufferSize);
      urlRequest.read(jByteBuffer!);
    },
    onRedirectReceived: (urlRequest, responseInfo, newLocationUrl) {
      if (!request.followRedirects) {
        urlRequest.cancel();
        responseCompleter.complete(StreamedResponse(
            const Stream.empty(), // Cronet provides no body for redirects.
            responseInfo.getHttpStatusCode(),
            contentLength: 0,
            reasonPhrase: responseInfo
                .getHttpStatusText()
                .toDartString(releaseOriginal: true),
            request: request,
            isRedirect: true,
            headers: _cronetToClientHeaders(responseInfo.getAllHeaders())));
        return;
      }
      ++numRedirects;
      if (numRedirects <= request.maxRedirects) {
        urlRequest.followRedirect();
      } else {
        urlRequest.cancel();
        responseCompleter.completeError(
            ClientException('Redirect limit exceeded', request.url));
      }
    },
    onReadCompleted: (urlRequest, responseInfo, byteBuffer) {
      byteBuffer.flip();
      responseStream!
          .add(jByteBuffer!.asUint8List().sublist(0, byteBuffer.remaining));

      byteBuffer.clear();
      urlRequest.read(byteBuffer);
    },
    onSucceeded: (urlRequest, responseInfo) {
      responseStream!.sink.close();
      jByteBuffer?.release();
    },
    onFailed: (urlRequest, responseInfo, cronetException) {
      final error = ClientException(
          'Cronet exception: ${cronetException.toString()}', request.url);
      if (responseStream == null) {
        responseCompleter.completeError(error);
      } else {
        responseStream!.addError(error);
        responseStream!.close();
      }
      jByteBuffer?.release();
    },
  ));
}

/// A HTTP [Client] based on the
/// [Cronet](https://developer.android.com/guide/topics/connectivity/cronet)
/// network stack.
///
/// For example:
/// ```
/// void main() async {
///   var client = CronetClient.defaultCronetEngine();
///   final response = await client.get(
///       Uri.https('www.googleapis.com', '/books/v1/volumes', {'q': '{http}'}));
///   if (response.statusCode != 200) {
///     throw HttpException('bad response: ${response.statusCode}');
///   }
///
///   final decodedResponse =
///       jsonDecode(utf8.decode(response.bodyBytes)) as Map;
///
///   final itemCount = decodedResponse['totalItems'];
///   print('Number of books about http: $itemCount.');
///   for (var i = 0; i < min(itemCount, 10); ++i) {
///     print(decodedResponse['items'][i]['volumeInfo']['title']);
///   }
/// }
/// ```
///
class CronetClient extends BaseClient {
  static final _executor = jb.Executors.newCachedThreadPool();
  CronetEngine? _engine;
  bool _isClosed = false;

  /// Indicates that [CronetClient] is responsible for closing [_engine].
  final bool _closeEngine;

  CronetClient._(this._engine, this._closeEngine) {
    Jni.initDLApi();
  }

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

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
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

    final stream = request.finalize();
    final body = await stream.toBytes();
    final responseCompleter = Completer<StreamedResponse>();

    final builder = engine._engine.newUrlRequestBuilder(
      request.url.toString().toJString(),
      jb.UrlRequestCallbackProxy.new1(
          _urlRequestCallbacks(request, responseCompleter)),
      _executor,
    )..setHttpMethod(request.method.toJString());

    var headers = request.headers;
    if (body.isNotEmpty &&
        !headers.keys.any((h) => h.toLowerCase() == 'content-type')) {
      // Cronet requires that requests containing upload data set a
      // 'Content-Type' header.
      headers = {...headers, 'content-type': 'application/octet-stream'};
    }
    headers.forEach((k, v) => builder.addHeader(k.toJString(), v.toJString()));

    if (body.isNotEmpty) {
      builder.setUploadDataProvider(
          jb.UploadDataProviders.create2(body.toJByteBuffer()), _executor);
    }
    builder.build().start();
    return responseCompleter.future;
  }
}
