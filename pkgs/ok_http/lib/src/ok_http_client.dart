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

// test-combined.p12 1234
import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:http_profile/http_profile.dart';
import 'package:jni/_internal.dart';
import 'package:jni/jni.dart';

import 'jni/bindings.dart' as bindings;

/// Configurations for the [OkHttpClient].
class OkHttpClientConfiguration {
  /// The maximum duration to wait for a call to complete.
  ///
  /// If a call does not finish within the specified time, it will throw a
  /// [ClientException] with the message "java.io.InterruptedIOException...".
  ///
  /// [Duration.zero] indicates no timeout.
  ///
  /// See [OkHttpClient.Builder.callTimeout](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-ok-http-client/-builder/call-timeout.html).
  final Duration callTimeout;

  /// The maximum duration to wait while connecting a TCP Socket to the target
  /// host.
  ///
  /// See [OkHttpClient.Builder.connectTimeout](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-ok-http-client/-builder/connect-timeout.html).
  final Duration connectTimeout;

  /// The maximum duration to wait for a TCP Socket and for individual read
  /// IO operations.
  ///
  /// See [OkHttpClient.Builder.readTimeout](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-ok-http-client/-builder/read-timeout.html).
  final Duration readTimeout;

  /// The maximum duration to wait for individual write IO operations.
  ///
  /// See [OkHttpClient.Builder.writeTimeout](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-ok-http-client/-builder/write-timeout.html).
  final Duration writeTimeout;

  const OkHttpClientConfiguration({
    this.callTimeout = Duration.zero,
    this.connectTimeout = const Duration(milliseconds: 10000),
    this.readTimeout = const Duration(milliseconds: 10000),
    this.writeTimeout = const Duration(milliseconds: 10000),
  });
}

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
/*
https://github.com/square/okhttp/blob/cc7e3c8e99402415b4fb72af3c2018e67acb918a/okhttp/src/test/java/okhttp3/internal/tls/ClientAuthTest.java#L265
https://square.github.io/okhttp/3.x/okhttp-tls/index.html?okhttp3/tls/HandshakeCertificates.html
https://stackoverflow.com/questions/65283321/okhttp-mutual-ssl-in-android

*/
class OkHttpClient extends BaseClient {
  late bindings.OkHttpClient _client;
  bool _isClosed = false;

  /// The configuration for this client, applied on a per-call basis.
  /// It can be updated multiple times during the client's lifecycle.
  OkHttpClientConfiguration configuration;

  static Future<String> getAlias() async {
    final c = Completer<String>();
    final activity = Jni.getCurrentActivity();
    bindings.KeyChain.choosePrivateKeyAlias(JObject.fromReference(activity),
        bindings.KeyChainAliasCallback.implement(
            bindings.$KeyChainAliasCallback(alias: (alias) {
      print('alias: $alias');
      final context = JObject.fromReference(Jni.getCachedApplicationContext());
      final pk = bindings.KeyChain.getPrivateKey(context, alias);
      final chain = bindings.KeyChain.getCertificateChain(context, alias);
      print('pk/chain (callback): ${pk.isNull} ${chain.isNull}');
      if (!pk.isNull) {
        print(
            'pk algorithm: ${pk.as(bindings.Key.type).getAlgorithm().toDartString()}');
      }
      c.complete(alias.toDartString());
    })),
        JArray.fromReference(JString.type, jNullReference),
        JArray.fromReference(JObject.type, jNullReference),
        JString.fromReference(jNullReference),
        -1,
        JString.fromReference(jNullReference));
    return c.future;
  }

  /// Creates a new instance of [OkHttpClient] with the given [configuration].
  OkHttpClient({
    this.configuration = const OkHttpClientConfiguration(),
    required String alias,
  }) {
    final context = JObject.fromReference(Jni.getCachedApplicationContext());
    final pk = bindings.KeyChain.getPrivateKey(context, alias.toJString());
    final chain =
        bindings.KeyChain.getCertificateChain(context, alias.toJString());
    print('pk/chain: ${pk.isNull} ${chain.isNull}');
    final trustManagerFactory = bindings.TrustManagerFactory.getInstance(
        bindings.TrustManagerFactory.getDefaultAlgorithm());
    trustManagerFactory.init(bindings.KeyStore.fromReference(jNullReference));
    final trustManagers = trustManagerFactory.getTrustManagers();

    final keyManagerFactory = bindings.KeyManagerFactory.getInstance(
        bindings.KeyManagerFactory.getDefaultAlgorithm());
    keyManagerFactory.init(bindings.KeyStore.fromReference(jNullReference),
        JArray.fromReference(jchar.type, jNullReference));
//    keyManagerFactory.init$1(JObject.fromReference(jNullReference));

    final trustManager = bindings.X509TrustManager.implement(
        bindings.$X509TrustManager(checkClientTrusted: (chain, authType) {
      print('checkClientTrusted');
    }, checkServerTrusted: (chain, authType) {
      print('checkServerTrusted');
    }, getAcceptedIssuers: () {
      print('getAcceptedIssuers');
      final factory = bindings.TrustManagerFactory.getInstance(
          bindings.TrustManagerFactory.getDefaultAlgorithm());
      factory.init(bindings.KeyStore.fromReference(jNullReference));
      return JArray(bindings.X509Certificate.type, 0);
    }));

    final km = bindings.$X509KeyManager(
        chooseClientAlias: (strings, principals, socket) {
          print('chooseClientAlias');
          return alias.toJString();
        },
        getClientAliases: (string, principals) {
          print('getClientAliases');
          return JArray(JString.type, 1)..[0] = alias.toJString();
        },
        getServerAliases: (string, principals) => JArray(JString.type, 0),
        chooseServerAlias: (string, principals, socket) => "".toJString(),
        getCertificateChain: (alias) {
          print('getCertificateChain: $alias');
          return JArray(bindings.X509Certificate.type, 0);
        },
        getPrivateKey: (alias) {
          print('getPrivateKey: $alias');
          return bindings.PrivateKey.fromReference(jNullReference);
        });
/*
    final generator = bindings.KeyPairGenerator.getInstance("RSA".toJString());
    final keyPair = generator.genKeyPair();

    final privateKey = keyPair.getPrivate();

    final serverRootCa = bindings.HeldCertificate_Builder()
        .serialNumber$1(1)
        .certificateAuthority(1)
        .commonName("root".toJString())
        .addSubjectAlternativeName("root_ca.com".toJString())
        .build();

    final clientIntermediateCa = bindings.HeldCertificate_Builder()
        .signedBy(serverRootCa)
        .certificateAuthority(0)
        .serialNumber$1(2)
        .commonName("intermediate_ca".toJString())
        .addSubjectAlternativeName("intermediate_ca.com".toJString())
        .build();

    final clientCert = bindings.HeldCertificate_Builder()
        .signedBy(clientIntermediateCa)
        .serialNumber$1(4)
        .commonName("Jethro Willis".toJString())
        .addSubjectAlternativeName("jethrowillis.com".toJString())
        .build();
    final privateKeyChain = JArray(bindings.X509Certificate.type, 1)
      ..[0] = clientIntermediateCa.certificate();
*/
    final sslContext = bindings.SSLContext.getInstance('TLS'.toJString())
      ..init(
          JArray(bindings.KeyManager.type, 1)
            ..[0] = bindings.X509Foo(chain, pk, alias.toJString())
                .as(bindings.KeyManager.type),
//            ..[0] = bindings.X509KeyManager.implement(km)
//                .as(bindings.KeyManager.type),
          JArray(bindings.TrustManager.type, 1)
            ..[0] = trustManager.as(bindings.TrustManager.type),
//          trustManagers,
          bindings.SecureRandom.fromReference(jNullReference));
    print('Creating client');
    _client = bindings.OkHttpClient_Builder()
        .sslSocketFactory$1(sslContext.getSocketFactory(),
            trustManagers[0].as(bindings.X509TrustManager.type))
        .build();
  }

  @override
  void close() {
    if (!_isClosed) {
      // Refer to OkHttp documentation for the shutdown procedure:
      // https://square.github.io/okhttp/5.x/okhttp/okhttp3/-ok-http-client/index.html#:~:text=Shutdown

      _client.dispatcher().executorService().shutdown();

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

    var reqBuilder = bindings.Request_Builder().url$1(requestUrl.toJString());

    requestHeaders.forEach((headerName, headerValue) {
      reqBuilder.addHeader(headerName.toJString(), headerValue.toJString());
    });

    // OkHttp doesn't allow a non-null RequestBody for GET and HEAD requests.
    // So, we need to handle this case separately.
    bindings.RequestBody okReqBody;
    if (requestMethod != 'GET' && requestMethod != 'HEAD') {
      okReqBody = bindings.RequestBody.create$10(requestBody.toJArray());
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
                bindings.$RedirectReceivedCallback(
          onRedirectReceived: (response, newLocation) {
            profile?.responseData.addRedirect(HttpProfileRedirectData(
              statusCode: response.code(),
              method: response
                  .request()
                  .method()
                  .toDartString(releaseOriginal: true),
              location: newLocation.toDartString(releaseOriginal: true),
            ));
          },
        )))
        .callTimeout(configuration.callTimeout.inMilliseconds,
            bindings.TimeUnit.MILLISECONDS)
        .connectTimeout(configuration.connectTimeout.inMilliseconds,
            bindings.TimeUnit.MILLISECONDS)
        .readTimeout(configuration.readTimeout.inMilliseconds,
            bindings.TimeUnit.MILLISECONDS)
        .writeTimeout(configuration.writeTimeout.inMilliseconds,
            bindings.TimeUnit.MILLISECONDS)
        .build();

    // `enqueue()` schedules the request to be executed in the future.
    // https://square.github.io/okhttp/5.x/okhttp/okhttp3/-call/enqueue.html
    reqConfiguredClient
        .newCall(reqBuilder.build())
        .enqueue(bindings.Callback.implement(bindings.$Callback(
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
                  bindings.$DataCallback(
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

  OkHttpClientWithProfile() : super(alias: 'XXX');
}

extension on Uint8List {
  JArray<jbyte> toJArray() =>
      JArray(jbyte.type, length)..setRange(0, length, this);
}

extension on JArray<jbyte> {
  Uint8List toUint8List({int? length}) =>
      getRange(0, length ?? this.length).buffer.asUint8List();
}
