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
import 'package:jni/jni.dart';

import 'third_party/okhttp3/_package.dart' as bindings;

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

  OkHttpClient() {
    _client = bindings.OkHttpClient.new1();
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    var requestUrl = request.url.toString();
    var requestHeaders = request.headers;
    var requestMethod = request.method;
    var requestBody = await request.finalize().toBytes();

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

    // `enqueue()` schedules the request to be executed in the future.
    // https://square.github.io/okhttp/5.x/okhttp/okhttp3/-call/enqueue.html
    _client
        .newCall(reqBuilder.build())
        .enqueue(bindings.Callback.implement(bindings.$CallbackImpl(
          onResponse: (bindings.Call call, bindings.Response response) {
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

            // Exceptions while reading the response body such as
            // `java.net.ProtocolException` & `java.net.SocketTimeoutException`
            // crash the app if un-handled.
            var responseBody = Uint8List.fromList([]);
            try {
              // Blocking call to read the response body.
              responseBody = response.body().bytes().toUint8List();
            } catch (e) {
              responseCompleter
                  .completeError(ClientException(e.toString(), request.url));
              return;
            }

            responseCompleter.complete(StreamedResponse(
              Stream.value(responseBody),
              response.code(),
              reasonPhrase:
                  response.message().toDartString(releaseOriginal: true),
              headers: responseHeaders,
              request: request,
              contentLength: contentLength,
            ));
          },
          onFailure: (bindings.Call call, JObject ioException) {
            responseCompleter.completeError(
                ClientException(ioException.toString(), request.url));
          },
        )));

    return responseCompleter.future;
  }
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
