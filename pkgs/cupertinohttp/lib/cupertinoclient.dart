// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart';

import 'cupertinohttp.dart';

class _TaskTracker {
  final responseCompleter = Completer<URLResponse>();
  final BaseRequest request;
  final responseController = StreamController<Uint8List>();
  int numRedirects = 0;

  _TaskTracker(this.request);

  void close() {
    responseController.close();
  }
}

/// A HTTP [Client] based on the
/// [Foundation URL Loading System](https://developer.apple.com/documentation/foundation/url_loading_system).
///
/// For example:
/// ```
/// void main() async {
///   var client = CupertinoClient.defaultSessionConfiguration();
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
class CupertinoClient extends BaseClient {
  static final Map<int, _TaskTracker> _tasks = {};

  URLSession _urlSession;

  CupertinoClient._(this._urlSession);

  static _TaskTracker _tracker(URLSessionTask task) =>
      _tasks[task.taskIdentifier]!;

  static void _onComplete(
      URLSession session, URLSessionTask task, Error? error) {
    final taskTracker = _tracker(task);

    if (error != null) {
      final exception =
          ClientException(error.localizedDescription ?? 'Unknown');
      if (taskTracker.responseCompleter.isCompleted) {
        taskTracker.responseController.addError(exception);
      } else {
        taskTracker.responseCompleter.completeError(exception);
      }
    } else if (!taskTracker.responseCompleter.isCompleted) {
      taskTracker.responseCompleter.completeError(
          StateError('task completed without an error or response'));
    }
    taskTracker.close();
    _tasks.remove(task.taskIdentifier);
  }

  static void _onData(URLSession session, URLSessionTask task, Data data) {
    final taskTracker = _tracker(task);
    taskTracker.responseController.add(data.bytes);
  }

  static URLRequest? _onRedirect(URLSession session, URLSessionTask task,
      HTTPURLResponse response, URLRequest request) {
    final taskTracker = _tracker(task);
    ++taskTracker.numRedirects;
    if (taskTracker.request.followRedirects &&
        taskTracker.numRedirects <= taskTracker.request.maxRedirects) {
      return request;
    }
    return null;
  }

  static URLSessionResponseDisposition _onResponse(
      URLSession session, URLSessionTask task, URLResponse response) {
    final taskTracker = _tracker(task);
    taskTracker.responseCompleter.complete(response);
    return URLSessionResponseDisposition.urlSessionResponseAllow;
  }

  /// A [Client] with the default configuration.
  factory CupertinoClient.defaultSessionConfiguration() {
    final config = URLSessionConfiguration.defaultSessionConfiguration();
    return CupertinoClient.fromSessionConfiguration(config);
  }

  /// A [Client] configured with a [URLSessionConfiguration].
  factory CupertinoClient.fromSessionConfiguration(
      URLSessionConfiguration config) {
    final session = URLSession.sessionWithConfiguration(config,
        onComplete: _onComplete,
        onData: _onData,
        onRedirect: _onRedirect,
        onResponse: _onResponse);
    return CupertinoClient._(session);
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // The expected sucess case flow (without redirects) is:
    // 1. send is called by BaseClient
    // 2. send starts the request with UrlSession.dataTaskWithRequest and waits
    //    on a Completer
    // 3. _onResponse is called with the HTTP headers, status code, etc.
    // 4. _onResponse calls complete on the Completer that send is waiting on.
    // 5. send continues executing and returns a StreamedResponse.
    //    StreamedResponse contains a Stream<UInt8List>.
    // 6. _onData is called one or more times and adds that to the
    //    StreamController that controls the Stream<UInt8List>
    // 7. _onComplete is called after all the data is read and closes the
    //    StreamController
    final stream = request.finalize();

    final bytes = await stream.toBytes();
    final d = Data.fromUint8List(bytes);

    final urlRequest = MutableURLRequest.fromUrl(request.url)
      ..httpMethod = request.method
      ..httpBody = d;

    // This will preserve Apple default headers - is that what we want?
    request.headers.forEach(urlRequest.setValueForHttpHeaderField);

    final task = _urlSession.dataTaskWithRequest(urlRequest);
    final taskTracker = _TaskTracker(request);
    _tasks[task.taskIdentifier] = taskTracker;
    task.resume();

    final maxRedirects = request.followRedirects ? request.maxRedirects : 0;

    final result = await taskTracker.responseCompleter.future;
    final response = result as HTTPURLResponse;

    if (request.followRedirects && taskTracker.numRedirects > maxRedirects) {
      throw ClientException('Redirect limit exceeded', request.url);
    }

    return StreamedResponse(
      taskTracker.responseController.stream,
      response.statusCode,
      contentLength: response.expectedContentLength == -1
          ? null
          : response.expectedContentLength,
      isRedirect: !request.followRedirects && taskTracker.numRedirects > 0,
      headers: response.allHeaderFields
          .map((key, value) => MapEntry(key.toLowerCase(), value)),
    );
  }
}
