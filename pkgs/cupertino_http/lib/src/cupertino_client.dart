// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:http_profile/http_profile.dart';
import 'package:objective_c/objective_c.dart';

import 'cupertino_api.dart';

final _digitRegex = RegExp(r'^\d+$');

final _supportsPerTaskDelegates = checkOSVersion(
  iOS: Version(15, 0, 0),
  macOS: Version(12, 0, 0),
);

/// A [ClientException] generated from an [NSError].
class NSErrorClientException extends ClientException {
  final NSError error;

  NSErrorClientException(this.error, [Uri? uri])
    : super(error.localizedDescription.toDartString(), uri);

  @override
  String toString() {
    final b = StringBuffer(
      'NSErrorClientException: ${error.localizedDescription.toDartString()} '
      '[domain=${error.domain.toDartString()}, code=${error.code}]',
    );

    if (uri != null) {
      b.write(', uri=$uri');
    }
    return b.toString();
  }
}

/// This class can be removed when `package:http` v2 is released.
class _StreamedResponseWithUrl extends StreamedResponse
    implements BaseResponseWithUrl {
  @override
  final Uri url;

  _StreamedResponseWithUrl(
    super.stream,
    super.statusCode, {
    required this.url,
    super.contentLength,
    super.request,
    super.headers,
    super.isRedirect,
    super.reasonPhrase,
  });
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
  URLSession? _urlSession;

  /// Whether this client owns the underlying session.
  ///
  /// If `true`, [close] will invalidate the session.
  /// If `false`, the session is managed externally and [close] only marks
  /// this client as closed.
  final bool _ownsSession;

  CupertinoClient._(this._urlSession) : _ownsSession = true;

  /// Creates a client from an externally-managed [URLSession].
  ///
  /// The session's lifecycle is managed externally - calling [close] will
  /// NOT invalidate the underlying session.
  ///
  /// This is useful for sharing a pre-configured session across isolates,
  /// where native code manages the session lifecycle and SSL/auth delegates.
  ///
  /// Example:
  /// ```dart
  /// // Get a shared session from native code
  /// final sessionPointer = MyNativeManager.getSharedSessionPointer();
  /// final session = URLSession.fromRawPointer(sessionPointer);
  /// final client = CupertinoClient.fromSharedSession(session);
  ///
  /// // Use the client
  /// final response = await client.get(Uri.parse('https://example.com'));
  ///
  /// // Closing the client does NOT affect the shared session
  /// client.close();
  /// ```
  CupertinoClient.fromSharedSession(URLSession session)
    : _urlSession = session,
      _ownsSession = false;

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

  /// A [Client] with the default configuration.
  factory CupertinoClient.defaultSessionConfiguration() {
    final config = URLSessionConfiguration.defaultSessionConfiguration();
    return CupertinoClient.fromSessionConfiguration(config);
  }

  /// A [Client] configured with a [URLSessionConfiguration].
  factory CupertinoClient.fromSessionConfiguration(
    URLSessionConfiguration config,
  ) {
    final session = URLSession.sessionWithConfiguration(config);
    return CupertinoClient._(session);
  }

  @override
  void close() {
    if (_ownsSession) {
      _urlSession?.finishTasksAndInvalidate();
    }
    _urlSession = null;
  }

  /// Returns true if [stream] includes at least one list with an element.
  ///
  /// Since [_hasData] consumes [stream], returns a new stream containing the
  /// equivalent data.
  static Future<(bool, Stream<List<int>>)> _hasData(
    Stream<List<int>> stream,
  ) async {
    final queue = StreamQueue(stream);
    while (await queue.hasNext && (await queue.peek).isEmpty) {
      await queue.next;
    }

    return (await queue.hasNext, queue.rest);
  }

  HttpClientRequestProfile? _createProfile(BaseRequest request) =>
      HttpClientRequestProfile.profile(
        requestStartTime: DateTime.now(),
        requestMethod: request.method,
        requestUri: request.url.toString(),
      );

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
        'HTTP request failed. Client is already closed.',
        request.url,
      );
    }
    final urlSession = _urlSession!;

    final stream = request.finalize();

    final profile = _createProfile(request);
    profile?.connectionInfo = {
      'package': 'package:cupertino_http',
      'client': 'CupertinoClient',
      'configuration': _urlSession!.configuration.toString(),
    };
    profile?.requestData
      ?..contentLength = request.contentLength
      ..followRedirects = request.followRedirects
      ..headersCommaValues = request.headers
      ..maxRedirects = request.maxRedirects;

    final urlRequest = MutableURLRequest.fromUrl(request.url)
      ..httpMethod = request.method;

    if (request.contentLength != null) {
      profile?.requestData.headersListValues = {
        'Content-Length': ['${request.contentLength}'],
        ...profile.requestData.headers!,
      };
      urlRequest.setValueForHttpHeaderField(
        'Content-Length',
        '${request.contentLength}',
      );
    }

    NSInputStream? nsStream;
    if (request is Request) {
      // Optimize the (typical) `Request` case since assigning to
      // `httpBodyStream` requires a lot of expensive setup and data passing.
      urlRequest.httpBody = request.bodyBytes.toNSData();
      profile?.requestData.bodySink.add(request.bodyBytes);
    } else if (await _hasData(stream) case (true, final s)) {
      // If the request is supposed to be bodyless (e.g. GET requests)
      // then setting `httpBodyStream` will cause the request to fail -
      // even if the stream is empty.
      if (profile == null) {
        nsStream = s.toNSInputStream();
        urlRequest.httpBodyStream = nsStream;
      } else {
        final splitter = StreamSplitter(s);
        nsStream = splitter.split().toNSInputStream();
        urlRequest.httpBodyStream = nsStream;
        unawaited(profile.requestData.bodySink.addStream(splitter.split()));
      }
    }

    // This will preserve Apple default headers - is that what we want?
    request.headers.forEach(urlRequest.setValueForHttpHeaderField);

    // For shared sessions (created externally), use streaming helper since
    // delegate callbacks are not connected to this client.
    // StreamingTask requires iOS 15+ / macOS 12+ for per-task delegates.
    // On older OS versions, fall back to buffered completion handler.
    if (!_supportsPerTaskDelegates) {
      return _sendBuffer(urlSession, urlRequest, request, nsStream);
    }

    final task = StreamingTask(
      session: urlSession,
      request: urlRequest,
      maxRedirects: request.followRedirects ? request.maxRedirects : 0,
      mapError: _mapError,
      profile: profile,
    )..start();

    if (request case Abortable(:final abortTrigger?)) {
      unawaited(abortTrigger.whenComplete(task.cancel));
    }

    final URLResponse urlResponse;
    try {
      urlResponse = await task.response;
    } catch (e) {
      unawaited(profile?.requestData.closeWithError(e.toString()));
      rethrow;
    } finally {
      if (nsStream?.streamStatus != NSStreamStatus.NSStreamStatusClosed) {
        nsStream?.close();
      }
    }

    final response = urlResponse as HTTPURLResponse;
    if (request.followRedirects && task.numRedirects > request.maxRedirects) {
      throw ClientException('Redirect limit exceeded', request.url);
    }

    final responseHeaders = _getResponseHeaders(response, request);
    final contentLength = response.expectedContentLength == -1
        ? null
        : response.expectedContentLength;
    final isRedirect = !request.followRedirects && task.numRedirects > 0;
    final reasonPhrase = _findReasonPhrase(response.statusCode);

    unawaited(profile?.requestData.close());
    if (profile != null) {
      profile.responseData
        ..contentLength = contentLength
        ..headersCommaValues = responseHeaders
        ..isRedirect = isRedirect
        ..reasonPhrase = reasonPhrase
        ..startTime = DateTime.now()
        ..statusCode = response.statusCode;
    }

    final responseStream = profile == null
        ? task.data
        : _profileStream(task.data, profile);

    return _StreamedResponseWithUrl(
      responseStream,
      response.statusCode,
      url: task.lastUrl ?? request.url,
      contentLength: contentLength,
      reasonPhrase: reasonPhrase,
      request: request,
      isRedirect: isRedirect,
      headers: responseHeaders,
    );
  }

  /// Sends request using dataTaskWithCompletionHandler for external sessions
  /// on iOS < 15 / macOS < 12 where per-task delegates are not available.
  Future<StreamedResponse> _sendBuffer(
    URLSession session,
    URLRequest urlRequest,
    BaseRequest request,
    NSInputStream? nsStream,
  ) {
    final completer = Completer<StreamedResponse>();

    final task = session.dataTaskWithCompletionHandler(urlRequest, (
      data,
      urlResponse,
      error,
    ) {
      if (nsStream?.streamStatus != NSStreamStatus.NSStreamStatusClosed) {
        nsStream?.close();
      }

      if (error != null) {
        completer.completeError(_mapError(error, urlRequest));
        return;
      }

      if (urlResponse == null) {
        completer.completeError(ClientException('No response', request.url));
        return;
      }

      final response = urlResponse as HTTPURLResponse;
      final responseHeaders = _getResponseHeaders(response, request);

      final contentLength = response.expectedContentLength == -1
          ? null
          : response.expectedContentLength;

      completer.complete(
        StreamedResponse(
          data == null ? const Stream.empty() : Stream.value(data.toList()),
          response.statusCode,
          contentLength: contentLength,
          reasonPhrase: _findReasonPhrase(response.statusCode),
          request: request,
          headers: responseHeaders,
        ),
      );
    });

    if (request case Abortable(:final abortTrigger?)) {
      unawaited(abortTrigger.whenComplete(task.cancel));
    }

    task.resume();
    return completer.future;
  }

  Map<String, String> _getResponseHeaders(
    HTTPURLResponse response,
    BaseRequest request,
  ) {
    final headers = response.allHeaderFields;
    final contentLength = headers['content-length'];
    if (contentLength != null && !_digitRegex.hasMatch(contentLength)) {
      throw ClientException(
        'Invalid content-length header [$contentLength].',
        request.url,
      );
    }
    return headers;
  }

  /// Wraps [source] to forward data to the [profile] body sink,
  /// closing the profile on completion or error.
  Stream<Uint8List> _profileStream(
    Stream<Uint8List> source,
    HttpClientRequestProfile profile,
  ) => source.transform(
    StreamTransformer<Uint8List, Uint8List>.fromHandlers(
      handleData: (data, sink) {
        profile.responseData.bodySink.add(data);
        sink.add(data);
      },
      handleError: (error, stackTrace, sink) {
        unawaited(profile.responseData.closeWithError(error.toString()));
        sink.addError(error, stackTrace);
      },
      handleDone: (sink) {
        unawaited(profile.responseData.close());
        sink.close();
      },
    ),
  );

  Object _mapError(NSError error, URLRequest request) => error.isCancelled
      ? RequestAbortedException(request.url)
      : NSErrorClientException(error, request.url);
}

/// A test-only class that makes the [HttpClientRequestProfile] data available.
class CupertinoClientWithProfile extends CupertinoClient {
  HttpClientRequestProfile? profile;

  @override
  HttpClientRequestProfile? _createProfile(BaseRequest request) =>
      profile = super._createProfile(request);

  CupertinoClientWithProfile._(super._urlSession) : super._();

  factory CupertinoClientWithProfile.defaultSessionConfiguration() {
    final config = URLSessionConfiguration.defaultSessionConfiguration();
    final session = URLSession.sessionWithConfiguration(config);
    return CupertinoClientWithProfile._(session);
  }
}
