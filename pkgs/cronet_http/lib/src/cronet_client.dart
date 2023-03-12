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

import 'package:flutter/services.dart';
import 'package:http/http.dart';

import 'messages.dart' as messages;

final _api = messages.HttpApi();

final Finalizer<String> _cronetEngineFinalizer = Finalizer(_api.freeEngine);

/// The type of caching to use when making HTTP requests.
enum CacheMode {
  disabled,
  memory,
  diskNoHttp,
  disk,
}

/// An environment that can be used to make HTTP requests.
class CronetEngine {
  final String _engineId;

  CronetEngine._(String engineId) : _engineId = engineId;

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
  static Future<CronetEngine> build(
      {CacheMode? cacheMode,
      int? cacheMaxSize,
      bool? enableBrotli,
      bool? enableHttp2,
      bool? enablePublicKeyPinningBypassForLocalTrustAnchors,
      bool? enableQuic,
      String? storagePath,
      String? userAgent}) async {
    final response = await _api.createEngine(messages.CreateEngineRequest(
        cacheMode: cacheMode != null
            ? messages.CacheMode.values[cacheMode.index]
            : null,
        cacheMaxSize: cacheMaxSize,
        enableBrotli: enableBrotli,
        enableHttp2: enableHttp2,
        enablePublicKeyPinningBypassForLocalTrustAnchors:
            enablePublicKeyPinningBypassForLocalTrustAnchors,
        enableQuic: enableQuic,
        storagePath: storagePath,
        userAgent: userAgent));
    if (response.errorString != null) {
      if (response.errorType ==
          messages.ExceptionType.illegalArgumentException) {
        throw ArgumentError(response.errorString);
      }
      throw Exception(response.errorString);
    }
    final engine = CronetEngine._(response.engineId!);
    _cronetEngineFinalizer.attach(engine, engine._engineId);
    return engine;
  }

  void close() {
    _cronetEngineFinalizer.detach(this);
    _api.freeEngine(_engineId);
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
class CronetClient extends BaseClient {
  CronetEngine? _engine;
  Future<CronetEngine>? _engineFuture;
  bool _isClosed = false;

  /// Indicates that [_engine] was constructed as an implementation detail for
  /// this [CronetClient] (i.e. was not provided as a constructor argument) and
  /// should be closed when this [CronetClient] is closed.
  final bool _ownedEngine;

  CronetClient._(this._engineFuture, this._ownedEngine);

  /// A [CronetClient] that will be initialized with a new [CronetEngine].
  factory CronetClient.defaultCronetEngine() => CronetClient._(null, true);

  /// A [CronetClient] configured with a [CronetEngine].
  factory CronetClient.fromCronetEngine(CronetEngine engine) =>
      CronetClient._(Future.value(engine), false);

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
  factory CronetClient.fromCronetEngineFuture(Future<CronetEngine> engine) =>
      CronetClient._(engine, false);

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

    if (_engine == null) {
      // Create the future here rather than in the [fromCronetEngineFuture]
      // factory so that [close] does not have to await the future just to
      // close it in the case where [send] is never called.
      //
      // Assign to _engineFuture instead of just `await`ing the result of
      // `CronetEngine.build()` to prevent concurrent executions of `send`
      // from creating multiple [CronetEngine]s.
      _engineFuture ??= CronetEngine.build();
      try {
        _engine = await _engineFuture;
      } catch (e) {
        throw ClientException(
            'Exception building CronetEngine: ${e.toString()}', request.url);
      }
    }

    final stream = request.finalize();

    final body = await stream.toBytes();

    var headers = request.headers;
    if (body.isNotEmpty &&
        !headers.keys.any((h) => h.toLowerCase() == 'content-type')) {
      // Cronet requires that requests containing upload data set a
      // 'Content-Type' header.
      headers = {...headers, 'content-type': 'application/octet-stream'};
    }

    final response = await _api.start(messages.StartRequest(
      engineId: _engine!._engineId,
      url: request.url.toString(),
      method: request.method,
      headers: headers,
      body: body,
      followRedirects: request.followRedirects,
      maxRedirects: request.maxRedirects,
    ));

    final responseCompleter = Completer<messages.ResponseStarted>();
    final responseDataController = StreamController<Uint8List>();

    void raiseException(Exception exception) {
      if (responseCompleter.isCompleted) {
        responseDataController.addError(exception);
      } else {
        responseCompleter.completeError(exception);
      }
      responseDataController.close();
    }

    final e = EventChannel(response.eventChannel);
    e.receiveBroadcastStream().listen(
        (e) {
          final event = messages.EventMessage.decode(e as Object);
          switch (event.type) {
            case messages.EventMessageType.responseStarted:
              responseCompleter.complete(event.responseStarted!);
              break;
            case messages.EventMessageType.readCompleted:
              responseDataController.sink.add(event.readCompleted!.data);
              break;
            case messages.EventMessageType.tooManyRedirects:
              raiseException(
                  ClientException('Redirect limit exceeded', request.url));
              break;
            default:
              throw UnsupportedError('Unexpected event: ${event.type}');
          }
        },
        onDone: responseDataController.close,
        onError: (Object e) {
          final pe = e as PlatformException;
          raiseException(ClientException(pe.message!, request.url));
        });

    final result = await responseCompleter.future;
    final responseHeaders = result.headers
        .cast<String, List<Object?>>()
        .map((key, value) => MapEntry(key.toLowerCase(), value.join(',')));

    final contentLengthHeader = responseHeaders['content-length'];
    return StreamedResponse(responseDataController.stream, result.statusCode,
        contentLength: contentLengthHeader == null
            ? null
            : int.tryParse(contentLengthHeader),
        reasonPhrase: result.statusText,
        request: request,
        isRedirect: result.isRedirect,
        headers: responseHeaders);
  }
}
