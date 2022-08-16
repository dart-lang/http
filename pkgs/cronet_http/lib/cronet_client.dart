// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:http/http.dart';

import 'src/messages.dart';

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
  static late final HttpApi _api = HttpApi();

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final stream = request.finalize();

    final body = await stream.toBytes();

    var headers = request.headers;
    if (body.isNotEmpty &&
        !headers.keys.any((h) => h.toLowerCase() == 'content-type')) {
      // Cronet requires that requests containing upload data set a
      // 'Content-Type' header.
      headers = {...headers, 'content-type': 'application/octet-stream'};
    }

    final response = await _api.start(StartRequest(
        url: request.url.toString(),
        method: request.method,
        headers: headers,
        body: body,
        followRedirects: request.followRedirects,
        maxRedirects: request.maxRedirects));

    final responseCompleter = Completer<ResponseStarted>();
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
          final event = EventMessage.decode(e as Object);
          switch (event.type) {
            case EventMessageType.responseStarted:
              responseCompleter.complete(event.responseStarted!);
              break;
            case EventMessageType.readCompleted:
              responseDataController.sink.add(event.readCompleted!.data);
              break;
            case EventMessageType.tooManyRedirects:
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
    final responseHeaders = (result.headers.cast<String, List<Object?>>())
        .map((key, value) => MapEntry(key.toLowerCase(), value.join(',')));

    return StreamedResponse(responseDataController.stream, result.statusCode,
        contentLength: responseHeaders['content-lenght'] as int?,
        isRedirect: result.isRedirect,
        headers: responseHeaders);
  }
}
