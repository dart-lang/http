// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A [Client] implementation based on the
/// [Foundation URL Loading System](https://developer.apple.com/documentation/foundation/url_loading_system).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';

import 'cupertino_api.dart';

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
  static final Map<URLSessionTask, _TaskTracker> _tasks = {};

  URLSession? _urlSession;

  CupertinoClient._(URLSession urlSession) : _urlSession = urlSession;

  String? _findReasonPhrase(int statusCode) {
    switch (statusCode) {
      case HttpStatus.continue_:
        return 'Continue';
      case HttpStatus.switchingProtocols:
        return 'Switching Protocols';
      case HttpStatus.ok:
        return 'OK';
      case HttpStatus.created:
        return 'Created';
      case HttpStatus.accepted:
        return 'Accepted';
      case HttpStatus.nonAuthoritativeInformation:
        return 'Non-Authoritative Information';
      case HttpStatus.noContent:
        return 'No Content';
      case HttpStatus.resetContent:
        return 'Reset Content';
      case HttpStatus.partialContent:
        return 'Partial Content';
      case HttpStatus.multipleChoices:
        return 'Multiple Choices';
      case HttpStatus.movedPermanently:
        return 'Moved Permanently';
      case HttpStatus.found:
        return 'Found';
      case HttpStatus.seeOther:
        return 'See Other';
      case HttpStatus.notModified:
        return 'Not Modified';
      case HttpStatus.useProxy:
        return 'Use Proxy';
      case HttpStatus.temporaryRedirect:
        return 'Temporary Redirect';
      case HttpStatus.badRequest:
        return 'Bad Request';
      case HttpStatus.unauthorized:
        return 'Unauthorized';
      case HttpStatus.paymentRequired:
        return 'Payment Required';
      case HttpStatus.forbidden:
        return 'Forbidden';
      case HttpStatus.notFound:
        return 'Not Found';
      case HttpStatus.methodNotAllowed:
        return 'Method Not Allowed';
      case HttpStatus.notAcceptable:
        return 'Not Acceptable';
      case HttpStatus.proxyAuthenticationRequired:
        return 'Proxy Authentication Required';
      case HttpStatus.requestTimeout:
        return 'Request Time-out';
      case HttpStatus.conflict:
        return 'Conflict';
      case HttpStatus.gone:
        return 'Gone';
      case HttpStatus.lengthRequired:
        return 'Length Required';
      case HttpStatus.preconditionFailed:
        return 'Precondition Failed';
      case HttpStatus.requestEntityTooLarge:
        return 'Request Entity Too Large';
      case HttpStatus.requestUriTooLong:
        return 'Request-URI Too Long';
      case HttpStatus.unsupportedMediaType:
        return 'Unsupported Media Type';
      case HttpStatus.requestedRangeNotSatisfiable:
        return 'Requested range not satisfiable';
      case HttpStatus.expectationFailed:
        return 'Expectation Failed';
      case HttpStatus.internalServerError:
        return 'Internal Server Error';
      case HttpStatus.notImplemented:
        return 'Not Implemented';
      case HttpStatus.badGateway:
        return 'Bad Gateway';
      case HttpStatus.serviceUnavailable:
        return 'Service Unavailable';
      case HttpStatus.gatewayTimeout:
        return 'Gateway Time-out';
      case HttpStatus.httpVersionNotSupported:
        return 'Http Version not supported';
      default:
        return null;
    }
  }

  static _TaskTracker _tracker(URLSessionTask task) => _tasks[task]!;

  static void _onComplete(
      URLSession session, URLSessionTask task, Error? error) {
    final taskTracker = _tracker(task);

    if (error != null) {
      final exception = ClientException(
          error.localizedDescription ?? 'Unknown', taskTracker.request.url);
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
    _tasks.remove(task);
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
  void close() {
    _urlSession = null;
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // The expected success case flow (without redirects) is:
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
    if (_urlSession == null) {
      throw ClientException(
          'HTTP request failed. Client is already closed.', request.url);
    }
    final urlSession = _urlSession!;

    final stream = request.finalize();

    final bytes = await stream.toBytes();
    final d = Data.fromUint8List(bytes);

    final urlRequest = MutableURLRequest.fromUrl(request.url)
      ..httpMethod = request.method
      ..httpBody = d;

    // This will preserve Apple default headers - is that what we want?
    request.headers.forEach(urlRequest.setValueForHttpHeaderField);

    final task = urlSession.dataTaskWithRequest(urlRequest);
    final taskTracker = _TaskTracker(request);
    _tasks[task] = taskTracker;
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
      reasonPhrase: _findReasonPhrase(response.statusCode),
      request: request,
      isRedirect: !request.followRedirects && taskTracker.numRedirects > 0,
      headers: response.allHeaderFields
          .map((key, value) => MapEntry(key.toLowerCase(), value)),
    );
  }
}
