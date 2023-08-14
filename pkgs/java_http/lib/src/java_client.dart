// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:jni/jni.dart';
import 'package:path/path.dart';

import 'third_party/java/lang/System.dart';
import 'third_party/java/net/HttpURLConnection.dart';
import 'third_party/java/net/URL.dart';

final _digitRegex = RegExp(r'^\d+$');

// TODO: Add a description of the implementation.
// Look at the description of cronet_client.dart and cupertino_client.dart for
// examples.
// See https://github.com/dart-lang/http/pull/980#discussion_r1253697461.
class JavaClient extends BaseClient {
  void _initJVM() {
    if (!Platform.isAndroid) {
      Jni.spawnIfNotExists(dylibDir: join('build', 'jni_libs'));
    }

    // TODO: Determine if we can remove this.
    // It's a workaround to fix the tests not passing on GitHub CI.
    // See https://github.com/dart-lang/http/pull/987#issuecomment-1636170371.
    System.setProperty(
        'java.net.preferIPv6Addresses'.toJString(), 'true'.toJString());
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // TODO: Move the call to _initJVM() to the JavaClient constructor.
    // See https://github.com/dart-lang/http/pull/980#discussion_r1253700470.
    _initJVM();

    final receivePort = ReceivePort();
    final events = StreamQueue<dynamic>(receivePort);

    // We can't send a StreamedRequest to another Isolate.
    // But we can send Map<String, String>, String, UInt8List, Uri.
    final isolateRequest = (
      sendPort: receivePort.sendPort,
      url: request.url,
      method: request.method,
      headers: request.headers,
      body: await request.finalize().toBytes(),
    );

    // Could create a new class to hold the data for the isolate instead
    // of using a record.
    await Isolate.spawn(_isolateMethod, isolateRequest);
    //httpRequestIsolate.errors.listen(print);

    final statusCode = await events.next as int;
    final reasonPhrase = await events.next as String?;
    final responseHeaders = await events.next as Map<String, String>;
    final responseBody = events.rest
        .handleError((Object error) {
          print('error is not being caught');
        })
        .cast<List<int>>()
        .takeWhile((bytes) => !(bytes.length == 1 && bytes[0] == -1));

    return StreamedResponse(responseBody, statusCode,
        contentLength: _parseContentLengthHeader(request.url, responseHeaders),
        request: request,
        headers: responseHeaders,
        reasonPhrase: reasonPhrase);
  }

  // TODO: Rename _isolateMethod to something more descriptive.
  void _isolateMethod(
    ({
      SendPort sendPort,
      Uint8List body,
      Map<String, String> headers,
      String method,
      Uri url,
    }) request,
  ) {
    final httpUrlConnection = URL
        .ctor3(request.url.toString().toJString())
        .openConnection()
        .castTo(HttpURLConnection.type, deleteOriginal: true);

    request.headers.forEach((headerName, headerValue) {
      httpUrlConnection.setRequestProperty(
          headerName.toJString(), headerValue.toJString());
    });

    httpUrlConnection.setRequestMethod(request.method.toJString());
    _setRequestBody(httpUrlConnection, request.body);

    final statusCode = _statusCode(request.url, httpUrlConnection);
    request.sendPort.send(statusCode);

    final reasonPhrase = _reasonPhrase(httpUrlConnection);
    request.sendPort.send(reasonPhrase);

    final responseHeaders = _responseHeaders(httpUrlConnection);
    request.sendPort.send(responseHeaders);

    final receivedBytes = _responseBody(httpUrlConnection, request.sendPort);
    final contentLengthHeader = _parseContentLengthHeader(
      request.url,
      responseHeaders,
    );

    if (contentLengthHeader != null && contentLengthHeader != receivedBytes) {
      request.sendPort.send(ClientException(
        'Unexpected end of body',
        request.url,
      ));
    }

    httpUrlConnection.disconnect();
  }

  Stream<int> testStream() async* {
    yield 1;
    yield 2;
    yield 3;
  }

  void _setRequestBody(
    HttpURLConnection httpUrlConnection,
    Uint8List requestBody,
  ) {
    if (requestBody.isEmpty) return;

    httpUrlConnection.setDoOutput(true);

    httpUrlConnection.getOutputStream()
      ..write1(requestBody.toJArray())
      ..flush()
      ..close();
  }

  int _statusCode(Uri requestUrl, HttpURLConnection httpUrlConnection) {
    final statusCode = httpUrlConnection.getResponseCode();

    if (statusCode == -1) {
      throw ClientException(
          'Status code can not be discerned from the response.', requestUrl);
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
          .putIfAbsent(headerName.toDartString().toLowerCase(), () => [])
          .add(headerValue.toDartString());
    }

    return headers.map((key, value) => MapEntry(key, value.join(',')));
  }

  int? _parseContentLengthHeader(
    Uri requestUrl,
    Map<String, String> headers,
  ) {
    int? contentLength;
    switch (headers['content-length']) {
      case final contentLengthHeader?
          when !_digitRegex.hasMatch(contentLengthHeader):
        throw ClientException(
          'Invalid content-length header [$contentLengthHeader].',
          requestUrl,
        );
      case final contentLengthHeader?:
        contentLength = int.parse(contentLengthHeader);
    }

    return contentLength;
  }

  int _responseBody(
    HttpURLConnection httpUrlConnection,
    SendPort sendPort,
  ) {
    final responseCode = httpUrlConnection.getResponseCode();

    final inputStream = (responseCode >= 200 && responseCode <= 299)
        ? httpUrlConnection.getInputStream()
        : httpUrlConnection.getErrorStream();

    var receievedBytes = -1;
    int byte;
    do {
      // Sending -1 over the SendPort marks the end of the response body stream.
      byte = inputStream.read(); // IOException could be thrown here.
      sendPort.send([byte]);
      receievedBytes++;
    } while (byte != -1);

    // int byte;
    // while ((byte = inputStream.read()) != -1) {
    //   sendPort.send([byte]);
    // }
    inputStream.close();
    return receievedBytes;
  }
}

extension on Uint8List {
  JArray<jbyte> toJArray() =>
      JArray(jbyte.type, length)..setRange(0, length, this);
}
