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

    if (enableBrotli != null) {
      builder.enableBrotli(enableBrotli);
    }

    return CronetEngine._(builder.build());
  }

  void close() {
    _engine.delete();
  }
}

/// A HTTP [Client] based on the
/// [Cronet](https://developer.android.com/guide/topics/connectivity/cronet)
/// network stack.
///
/// For example:
/// ```
/// void main() async {
///   var client = CronetClient();
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

class Callback
    implements jb.$UrlRequestCallbackProxy_UrlRequestCallbackInterfaceImpl {
  @override
  void onCanceled(
      jb.UrlRequest urlRequest, jb.UrlResponseInfo urlResponseInfo) {
    // TODO: implement onCanceled
  }

  @override
  void onFailed(jb.UrlRequest urlRequest, jb.UrlResponseInfo urlResponseInfo,
      jb.CronetException cronetException) {
    // TODO: implement onFailed
  }

  @override
  void onReadCompleted(jb.UrlRequest urlRequest,
      jb.UrlResponseInfo urlResponseInfo, JObject byteBuffer) {
    // TODO: implement onReadCompleted
  }

  @override
  void onRedirectReceived(jb.UrlRequest urlRequest,
      jb.UrlResponseInfo urlResponseInfo, JString string) {
    // TODO: implement onRedirectReceived
  }

  @override
  void onResponseStarted(
      jb.UrlRequest urlRequest, jb.UrlResponseInfo urlResponseInfo) {
    // TODO: implement onResponseStarted
  }

  @override
  void onSucceeded(
      jb.UrlRequest urlRequest, jb.UrlResponseInfo urlResponseInfo) {
    // TODO: implement onSucceeded
  }
}

class CronetClient extends BaseClient {
  CronetEngine? _engine;
  bool _isClosed = false;

  /// Indicates that [_engine] was constructed as an implementation detail for
  /// this [CronetClient] (i.e. was not provided as a constructor argument) and
  /// should be closed when this [CronetClient] is closed.
  final bool _ownedEngine;

  CronetClient._(this._engine, this._ownedEngine);

  /// A [CronetClient] that will be initialized with a new [CronetEngine].
  factory CronetClient.defaultCronetEngine() => CronetClient._(null, true);

  /// A [CronetClient] configured with a [CronetEngine].
  factory CronetClient.fromCronetEngine(CronetEngine engine) =>
      CronetClient._(engine, false);

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
    if (!_isClosed && _ownedEngine) {
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

    final engine = CronetEngine.build();
    print('Engine built');
    print(engine._engine.getVersionString());
    final connection = engine._engine
        .openConnection(jb.URL.new3(request.url.toString().toJString()));

    final interface =
        jb.UrlRequestCallbackProxy_UrlRequestCallbackInterface.implement(
            jb.$UrlRequestCallbackProxy_UrlRequestCallbackInterfaceImpl(
      onReadCompleted: (urlRequest, urlResponseInfo, byteBuffer) {},
      onRedirectReceived: (urlRequest, urlResponseInfo, string) {},
      onResponseStarted: (urlRequest, urlResponseInfo) {},
      onSucceeded: (urlRequest, urlResponseInfo) {},
      onFailed: (jb.UrlRequest urlRequest, jb.UrlResponseInfo urlResponseInfo,
          jb.CronetException cronetException) {},
    ));
    print('Interface created!');
    engine._engine.newUrlRequestBuilder(
      request.url.toString().toJString(),
      jb.UrlRequestCallbackProxy.new1(interface),
      jb.Executors.newSingleThreadExecutor(),
    );

    throw UnsupportedError('yest');
  }
}
