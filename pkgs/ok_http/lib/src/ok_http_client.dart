// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// An Android Flutter plugin that exposes the
/// [OkHttp](https://square.github.io/okhttp/) HTTP client.
///
/// The platform interface must be initialized before using this plugin e.g. by
/// calling
/// [`WidgetsFlutterBinding.ensureInitialized`](https://api.flutter.dev/flutter/widgets/WidgetsFlutterBinding/ensureInitialized.html)
/// or
/// [`runApp`](https://api.flutter.dev/flutter/widgets/runApp.html).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:http_profile/http_profile.dart';
import 'package:jni/jni.dart';

import 'jni/bindings.dart' as bindings;

/// An HTTP [Client] utilizing the [OkHttp](https://square.github.io/okhttp/) client.
///
/// Example Usage:
/// ```
/// void main() async {
///   var client = OkHttpClient();
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
class OkHttpClient extends BaseClient {
  late bindings.OkHttpClient _client;
  bool _isClosed = false;

  OkHttpClient() {
    _client = bindings.OkHttpClient.new1();
  }

  @override
  void close() {
    if (!_isClosed) {
      // Refer to OkHttp documentation for the shutdown procedure:
      // https://square.github.io/okhttp/5.x/okhttp/okhttp3/-ok-http-client/index.html#:~:text=Shutdown

      // Bindings for `java.util.concurrent.ExecutorService` are erroneous.
      // https://github.com/dart-lang/native/issues/588
      // So, use the JClass API to call the `shutdown` method by its signature.
      _client
          .dispatcher()
          .executorService()
          .jClass
          .instanceMethodId('shutdown', '()V');

      // Remove all idle connections from the resource pool.
      _client.connectionPool().evictAll();

      // Close the cache and release the JNI reference to the client.
      var cache = _client.cache();
      if (!cache.isNull) {
        cache.close();
      }
      _client.release();
    }
    _isClosed = true;
  }

  HttpClientRequestProfile? _createProfile(BaseRequest request) =>
      HttpClientRequestProfile.profile(
          requestStartTime: DateTime.now(),
          requestMethod: request.method,
          requestUri: request.url.toString());

  void addProfileError(HttpClientRequestProfile? profile, Exception error) {
    if (profile != null) {
      if (profile.requestData.endTime == null) {
        profile.requestData.closeWithError(error.toString());
      } else {
        profile.responseData.closeWithError(error.toString());
      }
    }
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (_isClosed) {
      throw ClientException(
          'HTTP request failed. Client is already closed.', request.url);
    }

    final profile = _createProfile(request);
    profile?.connectionInfo = {
      'package': 'package:ok_http',
      'client': 'OkHttpClient',
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

    var requestUrl = request.url.toString();
    var requestHeaders = request.headers;
    var requestMethod = request.method;
    var requestBody = await request.finalize().toBytes();
    var maxRedirects = request.maxRedirects;
    var followRedirects = request.followRedirects;

    profile?.requestData.bodySink.add(requestBody);
    var profileRespClosed = false;

    final responseCompleter = Completer<StreamedResponse>();

    var reqBuilder = bindings.Request_Builder().url1(requestUrl.toJString());

    requestHeaders.forEach((headerName, headerValue) {
      reqBuilder.addHeader(headerName.toJString(), headerValue.toJString());
    });

    // OkHttp doesn't allow a non-null RequestBody for GET and HEAD requests.
    // So, we need to handle this case separately.
    bindings.RequestBody okReqBody;
    if (requestMethod != 'GET' && requestMethod != 'HEAD') {
      okReqBody = bindings.RequestBody.create10(requestBody.toJArray());
    } else {
      okReqBody = bindings.RequestBody.fromReference(jNullReference);
    }

    reqBuilder.method(
      requestMethod.toJString(),
      okReqBody,
    );

    // To configure the client per-request, we create a new client with the
    // builder associated with `_client`.
    // They share the same connection pool and dispatcher.
    // https://square.github.io/okhttp/recipes/#per-call-configuration-kt-java
    //
    // `followRedirects` is set to `false` to handle redirects manually.
    // (Since OkHttp sets a hard limit of 20 redirects.)
    // https://github.com/square/okhttp/blob/54238b4c713080c3fd32fb1a070fb5d6814c9a09/okhttp/src/main/kotlin/okhttp3/internal/http/RetryAndFollowUpInterceptor.kt#L350
    final reqConfiguredClient = bindings.RedirectInterceptor.Companion
        .addRedirectInterceptor(
            _client.newBuilder().followRedirects(false),
            maxRedirects,
            followRedirects, bindings.RedirectReceivedCallback.implement(
                bindings.$RedirectReceivedCallbackImpl(
      onRedirectReceived: (response, newLocation) {
        profile?.responseData.addRedirect(HttpProfileRedirectData(
          statusCode: response.code(),
          method:
              response.request().method().toDartString(releaseOriginal: true),
          location: newLocation.toDartString(releaseOriginal: true),
        ));
      },
    ))).build();

    // `enqueue()` schedules the request to be executed in the future.
    // https://square.github.io/okhttp/5.x/okhttp/okhttp3/-call/enqueue.html
    reqConfiguredClient
        .newCall(reqBuilder.build())
        .enqueue(bindings.Callback.implement(bindings.$CallbackImpl(
          onResponse: (bindings.Call call, bindings.Response response) {
            var reader = bindings.AsyncInputStreamReader();
            var respBodyStreamController = StreamController<List<int>>();

            var responseHeaders = <String, String>{};

            response.headers().toMultimap().forEach((key, value) {
              responseHeaders[key.toDartString(releaseOriginal: true)] =
                  value.join(',');
            });

            int? contentLength;
            if (responseHeaders.containsKey('content-length')) {
              contentLength = int.tryParse(responseHeaders['content-length']!);

              // To be conformant with RFC 2616 14.13, we need to check if the
              // content-length is a non-negative integer.
              if (contentLength == null || contentLength < 0) {
                responseCompleter.completeError(ClientException(
                    'Invalid content-length header', request.url));
                return;
              }
            }

            var responseBodyByteStream = response.body().byteStream();
            reader.readAsync(
                responseBodyByteStream,
                bindings.DataCallback.implement(
                  bindings.$DataCallbackImpl(
                    onDataRead: (JArray<jbyte> bytesRead) {
                      var data = bytesRead.toUint8List();

                      respBodyStreamController.sink.add(data);
                      profile?.responseData.bodySink.add(data);
                    },
                    onFinished: () {
                      reader.shutdown();
                      respBodyStreamController.sink.close();
                      if (!profileRespClosed) {
                        profile?.responseData.close();
                        profileRespClosed = true;
                      }
                    },
                    onError: (iOException) {
                      var exception =
                          ClientException(iOException.toString(), request.url);

                      respBodyStreamController.sink.addError(exception);
                      addProfileError(profile, exception);
                      profileRespClosed = true;

                      reader.shutdown();
                      respBodyStreamController.sink.close();
                    },
                  ),
                ));

            responseCompleter.complete(StreamedResponse(
              respBodyStreamController.stream,
              response.code(),
              reasonPhrase:
                  response.message().toDartString(releaseOriginal: true),
              headers: responseHeaders,
              request: request,
              contentLength: contentLength,
              isRedirect: response.isRedirect(),
            ));

            profile?.requestData.close();
            profile?.responseData
              ?..contentLength = contentLength
              ..headersCommaValues = responseHeaders
              ..isRedirect = response.isRedirect()
              ..reasonPhrase =
                  response.message().toDartString(releaseOriginal: true)
              ..startTime = DateTime.now()
              ..statusCode = response.code();
          },
          onFailure: (bindings.Call call, JObject ioException) {
            var msg = ioException.toString();
            if (msg.contains('Redirect limit exceeded')) {
              msg = 'Redirect limit exceeded';
            }
            var exception = ClientException(msg, request.url);
            responseCompleter.completeError(exception);
            addProfileError(profile, exception);
            profileRespClosed = true;
          },
        )));

    return responseCompleter.future;
  }
}

/// A test-only class that makes the [HttpClientRequestProfile] data available.
class OkHttpClientWithProfile extends OkHttpClient {
  HttpClientRequestProfile? profile;

  @override
  HttpClientRequestProfile? _createProfile(BaseRequest request) =>
      profile = super._createProfile(request);

  OkHttpClientWithProfile() : super();
}

extension on Uint8List {
  JArray<jbyte> toJArray() =>
      JArray(jbyte.type, length)..setRange(0, length, this);
}

extension on JArray<jbyte> {
  Uint8List toUint8List({int? length}) {
    length ??= this.length;
    final list = Uint8List(length);
    for (var i = 0; i < length; i++) {
      list[i] = this[i];
    }
    return list;
  }
}
