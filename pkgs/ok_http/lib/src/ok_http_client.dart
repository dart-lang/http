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
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:http_profile/http_profile.dart';
import 'package:jni/jni.dart';

import 'jni/bindings.dart' as bindings;
import 'jni/bindings.dart' show PrivateKey, X509Certificate;

class _JavaIOException extends IOException {
  final String _message;
  _JavaIOException(JniException e) : _message = e.message;

  @override
  String toString() => _message;
}

/// A [bindings.X509TrustManager] that trusts all certificates.
final _allAllTrustManager =
    bindings.X509TrustManager.implement(bindings.$X509TrustManager(
        checkClientTrusted: (chain, authType) {},
        checkServerTrusted: (chain, authType) {},
        getAcceptedIssuers: () {
          final factory = bindings.TrustManagerFactory.getInstance(
              bindings.TrustManagerFactory.getDefaultAlgorithm());
          factory!.init(null);
          return JArray(bindings.X509Certificate.nullableType, 0);
        })).as(bindings.TrustManager.type);

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

  /// The [PrivateKey] used for TLS Client Authentication.
  ///
  /// If set then [clientCertificateChain] must also be set.
  ///
  /// See [Introducing TLS with Client Authentication](https://blog.cloudflare.com/introducing-tls-client-auth/).
  final PrivateKey? clientPrivateKey;

  /// The certificate chain used for TLS Client Authentication.
  ///
  /// If set then [clientPrivateKey] must also be set.
  ///
  /// See [Introducing TLS with Client Authentication](https://blog.cloudflare.com/introducing-tls-client-auth/).
  final List<X509Certificate>? clientCertificateChain;

  /// Whether the certificate chain for server certificates will be validated.
  ///
  /// This should only be used in a testing environment.
  final bool validateServerCertificates;

  const OkHttpClientConfiguration({
    this.callTimeout = Duration.zero,
    this.connectTimeout = const Duration(milliseconds: 10000),
    this.readTimeout = const Duration(milliseconds: 10000),
    this.writeTimeout = const Duration(milliseconds: 10000),
    this.clientPrivateKey,
    this.clientCertificateChain,
    this.validateServerCertificates = true,
  });
}

/// Launches an Activity for the user to select the alias for a private key and
/// certificate pair for authentication. The selected alias or null will be
/// returned.
///
/// See [`KeyChain.choosePrivateKeyAlias`](https://developer.android.com/reference/android/security/KeyChain#choosePrivateKeyAlias(android.app.Activity,%20android.security.KeyChainAliasCallback,%20java.lang.String[],%20java.security.Principal[],%20android.net.Uri,%20java.lang.String).
Future<String?> choosePrivateKeyAlias({
  JObject? activity,
}) async {
  final c = Completer<String?>();
  activity ??= JObject.fromReference(Jni.getCurrentActivity());
  bindings.KeyChain.choosePrivateKeyAlias(activity,
      bindings.KeyChainAliasCallback.implement(
          bindings.$KeyChainAliasCallback(alias: (alias) {
    c.complete(alias?.toDartString());
  })), null, null, null, -1, null);
  return c.future;
}

/// Load a [PrivateKey] and certificate chain given a `KeyStore` alias.
///
/// See [Android Keystore system](https://developer.android.com/privacy-and-security/keystore).
(PrivateKey, List<X509Certificate>) loadPrivateKeyAndCertificateChainFromAlias(
    String alias,
    {JObject? context}) {
  context ??= JObject.fromReference(Jni.getCachedApplicationContext());
  final jAlias = alias.toJString();
  final pk = bindings.KeyChain.getPrivateKey(context, jAlias)!;
  final chain = bindings.KeyChain.getCertificateChain(context, jAlias)!;

  return (pk, chain.toList().cast<X509Certificate>());
}

/// Load a [PrivateKey] and certificate chain from a PKCS 12 archive.
///
/// Throws [IOException] if the password is incorrect or the PKCS12 data is
/// invalid.
(PrivateKey, List<X509Certificate>) loadPrivateKeyAndCertificateChainFromPKCS12(
    Uint8List pkcs12Data, String password,
    {JObject? context}) {
  context ??= JObject.fromReference(Jni.getCachedApplicationContext());
  var keyStore = bindings.KeyStore.getInstance('PKCS12'.toJString())!;

  final jPassword = JCharArray(password.length);
  for (var i = 0; i < password.length; ++i) {
    jPassword[i] = password[i].codeUnits[0];
  }
  try {
    keyStore.load(
        bindings.ByteArrayInputStream(JByteArray.from(pkcs12Data)), jPassword);
  } on JniException catch (e) {
    if (e.message.contains('java.io.IOException')) {
      throw _JavaIOException(e);
    }
  }

  if (keyStore.size() == 0) {
    throw ArgumentError('no key in PKC12 data', 'pkcs12Data');
  }

  if (keyStore.size() > 1) {
    throw ArgumentError('multiple entries in PKC12 data', 'pkcs12Data');
  }

  final aliases = keyStore.aliases()!;
  final jAlias = aliases.nextElement()!;

  final pk = keyStore.getKey(jAlias, jPassword);
  if (pk == null) {
    throw ArgumentError('no key in PKC12 data', 'pkcs12Data');
  }
  final jCertificates = keyStore.getCertificateChain(jAlias);
  if (jCertificates == null) {
    throw ArgumentError('no certificate chain in PKC12 data', 'pkcs12Data');
  }

  if (!pk.isA(PrivateKey.type)) {
    throw ArgumentError('certificate key is not a PrivateKey', 'pkcs12Data');
  }

  final certificates = jCertificates.map((c) {
    if (c == null || !c.isA(X509Certificate.type)) {
      throw ArgumentError(
          'certificate chain contains non-X509 certificates', 'pkcs12Data');
    }
    return c.as(X509Certificate.type);
  }).toList();
  return (pk.as(PrivateKey.type), certificates);
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
class OkHttpClient extends BaseClient {
  late bindings.OkHttpClient _client;
  bool _isClosed = false;

  /// The configuration for this client, applied on a per-call basis.
  /// It can be updated multiple times during the client's lifecycle.
  OkHttpClientConfiguration configuration;

  /// Creates a new instance of [OkHttpClient] with the given [configuration].
  OkHttpClient({
    this.configuration = const OkHttpClientConfiguration(),
//    required String alias,
  }) {
    final clientPrivateKey = configuration.clientPrivateKey;
    final clientCertificateChain = configuration.clientCertificateChain;

    if (clientPrivateKey != null && clientCertificateChain == null) {
      throw ArgumentError(
          'OkHttpClientConfiguration.clientCertificateChain must be set '
          'if OkHttpClientConfiguration.clientPrivateKey is set');
    }

    if (clientCertificateChain != null && clientPrivateKey == null) {
      throw ArgumentError(
          'OkHttpClientConfiguration.clientPrivateKey must be set '
          'if OkHttpClientConfiguration.clientCertificateChain is set');
    }

    final builder = bindings.OkHttpClient$Builder();
    if (clientPrivateKey != null ||
        clientCertificateChain != null ||
        !configuration.validateServerCertificates) {
      JArray<bindings.KeyManager>? keyManagers;
      final trustManagers = JArray(bindings.TrustManager.nullableType, 1);

      if (clientPrivateKey != null && clientCertificateChain != null) {
        final chain =
            JArray.of(bindings.X509Certificate.type, clientCertificateChain);
        final keyManager = bindings.FixedResponseX509ExtendedKeyManager(
            chain, clientPrivateKey, 'DUMMY'.toJString());
        keyManagers = JArray.filled(1, keyManager.as(bindings.KeyManager.type),
            E: bindings.KeyManager.type);
      }

      if (!configuration.validateServerCertificates) {
        trustManagers[0] = _allAllTrustManager;
      } else {
        final tmf = bindings.TrustManagerFactory.getInstance(
            bindings.TrustManagerFactory.getDefaultAlgorithm())!
          ..init(null);
        final tms = tmf.getTrustManagers()!;
        if (tms.length != 1) {
          throw StateError('unexpected XXX');
        }
        trustManagers[0] = tms[0]!;
      }

      final sslContext = bindings.SSLContext.getInstance('TLS'.toJString())!
        ..init(keyManagers, trustManagers, null);
      builder.sslSocketFactory$1(sslContext.getSocketFactory()!,
          trustManagers[0]!.as(bindings.X509TrustManager.type));
    }
    _client = builder.build();
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
      if (cache != null) {
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

    var reqBuilder = bindings.Request$Builder().url$1(requestUrl.toJString());

    requestHeaders.forEach((headerName, headerValue) {
      reqBuilder.addHeader(headerName.toJString(), headerValue.toJString());
    });

    // OkHttp doesn't allow a non-null RequestBody for GET and HEAD requests.
    // So, we need to handle this case separately.
    bindings.RequestBody? okReqBody;
    if (requestMethod != 'GET' && requestMethod != 'HEAD') {
      okReqBody = bindings.RequestBody.create$10(JByteArray.from(requestBody));
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

            var responseBodyByteStream = response.body()!.byteStream();
            reader.readAsync(
                responseBodyByteStream,
                bindings.DataCallback.implement(
                  bindings.$DataCallback(
                    onDataRead: (bytesRead) {
                      var data = bytesRead.toList(growable: false);

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
