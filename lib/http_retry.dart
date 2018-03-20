// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:async/async.dart';
import 'package:http/http.dart';

/// An HTTP client wrapper that automatically retries failing requests.
class RetryClient extends BaseClient {
  /// The wrapped client.
  final Client _inner;

  /// The number of times a request should be retried.
  final int _retries;

  /// The callback that determines whether a request should be retried.
  final bool Function(BaseResponse) _when;

  /// The callback that determines whether a request when an error is thrown.
  final bool Function(dynamic, StackTrace) _whenError;

  /// The callback that determines how long to wait before retrying a request.
  final Duration Function(int) _delay;

  /// The callback to call to indicate that a request is being retried.
  final void Function(BaseRequest, BaseResponse, int) _onRetry;

  /// Creates a client wrapping [inner] that retries HTTP requests.
  ///
  /// This retries a failing request [retries] times (3 by default). Note that
  /// `n` retries means that the request will be sent at most `n + 1` times.
  ///
  /// By default, this retries requests whose responses have status code 503
  /// Temporary Failure. If [when] is passed, it retries any request for whose
  /// response [when] returns `true`. If [whenError] is passed, it also retries
  /// any request that throws an error for which [whenError] returns `true`.
  ///
  /// By default, this waits 500ms between the original request and the first
  /// retry, then increases the delay by 1.5x for each subsequent retry. If
  /// [delay] is passed, it's used to determine the time to wait before the
  /// given (zero-based) retry.
  ///
  /// If [onRetry] is passed, it's called immediately before each retry so that
  /// the client has a chance to perform side effects like logging. The
  /// `response` parameter will be null if the request was retried due to an
  /// error for which [whenError] returned `true`.
  RetryClient(this._inner,
      {int retries,
      bool when(BaseResponse response),
      bool whenError(error, StackTrace stackTrace),
      Duration delay(int retryCount),
      void onRetry(BaseRequest request, BaseResponse response, int retryCount)})
      : _retries = retries ?? 3,
        _when = when ?? ((response) => response.statusCode == 503),
        _whenError = whenError ?? ((_, __) => false),
        _delay = delay ??
            ((retryCount) =>
                new Duration(milliseconds: 500) * math.pow(1.5, retryCount)),
        _onRetry = onRetry {
    RangeError.checkNotNegative(_retries, "retries");
  }

  /// Like [new RetryClient], but with a pre-computed list of [delays]
  /// between each retry.
  ///
  /// This will retry a request at most `delays.length` times, using each delay
  /// in order. It will wait for `delays[0]` after the initial request,
  /// `delays[1]` after the first retry, and so on.
  RetryClient.withDelays(Client inner, Iterable<Duration> delays,
      {bool when(BaseResponse response),
      bool whenError(error, StackTrace stackTrace),
      void onRetry(BaseRequest request, BaseResponse response, int retryCount)})
      : this._withDelays(inner, delays.toList(),
            when: when, whenError: whenError, onRetry: onRetry);

  RetryClient._withDelays(Client inner, List<Duration> delays,
      {bool when(BaseResponse response),
      bool whenError(error, StackTrace stackTrace),
      void onRetry(BaseRequest request, BaseResponse response, int retryCount)})
      : this(inner,
            retries: delays.length,
            delay: (retryCount) => delays[retryCount],
            when: when,
            whenError: whenError,
            onRetry: onRetry);

  Future<StreamedResponse> send(BaseRequest request) async {
    var splitter = new StreamSplitter(request.finalize());

    var i = 0;
    while (true) {
      StreamedResponse response;
      try {
        response = await _inner.send(_copyRequest(request, splitter.split()));
      } catch (error, stackTrace) {
        if (i == _retries || !_whenError(error, stackTrace)) rethrow;
      }

      if (response != null) {
        if (i == _retries || !_when(response)) return response;

        // Make sure the response stream is listened to so that we don't leave
        // dangling connections.
        response.stream.listen((_) {}).cancel()?.catchError((_) {});
      }

      await new Future.delayed(_delay(i));
      if (_onRetry != null) _onRetry(request, response, i);
      i++;
    }
  }

  /// Returns a copy of [original] with the given [body].
  StreamedRequest _copyRequest(BaseRequest original, Stream<List<int>> body) {
    var request = new StreamedRequest(original.method, original.url);
    request.contentLength = original.contentLength;
    request.followRedirects = original.followRedirects;
    request.headers.addAll(original.headers);
    request.maxRedirects = original.maxRedirects;
    request.persistentConnection = original.persistentConnection;

    body.listen(request.sink.add,
        onError: request.sink.addError,
        onDone: request.sink.close,
        cancelOnError: true);

    return request;
  }

  void close() => _inner.close();
}
