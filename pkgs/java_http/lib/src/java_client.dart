// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:jni/jni.dart';
import 'package:path/path.dart';

import 'third_party/java/net/HttpURLConnection.dart';
import 'third_party/java/net/URL.dart';

// TODO: Add a description of the implementation.
// Look at the description of cronet_client.dart and cupertino_client.dart for
// examples.
// See https://github.com/dart-lang/http/pull/980#discussion_r1253697461.
class JavaClient extends BaseClient {
  void _initJVM() {
    if (!Platform.isAndroid) {
      Jni.spawnIfNotExists(dylibDir: join('build', 'jni_libs'));
    }
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // TODO: Move the call to _initJVM() to the JavaClient constructor.
    // See https://github.com/dart-lang/http/pull/980#discussion_r1253700470.
    _initJVM();

    final (statusCode, reasonPhrase, responseHeaders, responseBody) =
        await Isolate.run(() {
      request.finalize();

      final httpUrlConnection = URL
          .ctor3(request.url.toString().toJString())
          .openConnection()
          .castTo(HttpURLConnection.type, deleteOriginal: true);

      request.headers.forEach((headerName, headerValue) {
        httpUrlConnection.setRequestProperty(
            headerName.toJString(), headerValue.toJString());
      });

      httpUrlConnection.setRequestMethod(request.method.toJString());

      final statusCode = _statusCode(request, httpUrlConnection);
      final reasonPhrase = _reasonPhrase(httpUrlConnection);
      final responseHeaders = _responseHeaders(httpUrlConnection);
      final responseBody = _responseBody(httpUrlConnection);

      httpUrlConnection.disconnect();

      return (
        statusCode,
        reasonPhrase,
        responseHeaders,
        responseBody,
      );
    });

    final contentLengthHeader = responseHeaders['content-length'];
    final contentLength = (contentLengthHeader == null)
        ? null
        : int.tryParse(contentLengthHeader);

    return StreamedResponse(Stream.value(responseBody), statusCode,
        contentLength: contentLength,
        request: request,
        headers: responseHeaders,
        reasonPhrase: reasonPhrase);
  }

  int _statusCode(BaseRequest request, HttpURLConnection httpUrlConnection) {
    final statusCode = httpUrlConnection.getResponseCode();

    if (statusCode == -1) {
      throw ClientException(
          'Status code can not be discerned from the response.', request.url);
    }

    return statusCode;
  }

  String? _reasonPhrase(HttpURLConnection httpUrlConnection) {
    final reasonPhrase = httpUrlConnection.getResponseMessage();

    return reasonPhrase.isNull
        ? null
        : reasonPhrase.toDartString(deleteOriginal: true);
  }

  Map<String, String> _responseHeaders(HttpURLConnection httpUrlConnection) {
    final headers = <String, List<String>>{};

    for (var i = 0;; i++) {
      final headerName = httpUrlConnection.getHeaderFieldKey(i);
      final headerValue = httpUrlConnection.getHeaderField1(i);

      // If the header name and header value are both null then we have reached
      // the end of the response headers.
      if (headerName.isNull && headerValue.isNull) break;

      // The HTTP response header status line is returned as a header field
      // where the field key is null and the field is the status line.
      // Other package:http implementations don't include the status line as a
      // header. So we don't add the status line to the headers.
      if (headerName.isNull) continue;

      headers
          .putIfAbsent(headerName.toDartString(), () => [])
          .add(headerValue.toDartString());
    }

    return headers
        .map((key, value) => MapEntry(key.toLowerCase(), value.join(',')));
  }

  Uint8List _responseBody(HttpURLConnection httpUrlConnection) {
    final responseCode = httpUrlConnection.getResponseCode();

    final inputStream = (responseCode >= 200 && responseCode <= 299)
        ? httpUrlConnection.getInputStream()
        : httpUrlConnection.getErrorStream();

    final bytes = <int>[];
    int byte;
    while ((byte = inputStream.read()) != -1) {
      bytes.add(byte);
    }

    inputStream.close();

    return Uint8List.fromList(bytes);
  }
}
