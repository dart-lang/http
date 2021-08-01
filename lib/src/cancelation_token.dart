import 'dart:async';

import 'exception.dart';

typedef _AbortFunc = void Function();

class CancellationToken {
  /// Will automatically dispose the token after a request has been completed.
  ///
  /// Set it to `true` when you use the token for a single request.
  ///
  /// For retries or multi-request, set this to `false` and
  /// `completeToken()` has to be called manually.
  final bool autoDispose;

  bool _cancellationPending = false;

  final _cancellationStreamController = StreamController<void>.broadcast();
  final _requestSubscriptions = <dynamic, StreamSubscription<void>>{};

  CancellationToken({required this.autoDispose});

  /// If token is not disposed yet
  bool get isDisposed => _cancellationStreamController.isClosed;

  Future _cancel() {
    _cancellationPending = true;

    if (_cancellationStreamController.hasListener) {
      _cancellationStreamController.add(null);
      if (autoDispose) {
        return disposeToken();
      }
    }

    return Future.value();
  }

  /// Cancels all registered requests and eventually disposes the token
  Future cancel() {
    if (!isDisposed) {
      return _cancel();
    }

    throw CancellationTokenException('Token already disposed', this);
  }

  _AbortFunc? _getAbortOfRequest(dynamic request) {
    //We have to do this completely dynamically, because no imports for
    //typechecking are possible
    try {
      // ignore: avoid_dynamic_calls
      return request.abort as _AbortFunc;
      // ignore: avoid_catching_errors
    } on Error catch (_) {
      return null;
    }
  }

  /// Check if a request and it's type is supported by the token
  bool isRequestSupported(dynamic request) =>
      _getAbortOfRequest(request) != null;

  /// Registers a request
  ///
  /// You only have to call this, when you are manually working with `Request`'s
  /// yourself. Elsewise it is handled by `Client`.
  Future registerRequest(dynamic request) {
    if (!isDisposed) {
      final abortFunc = _getAbortOfRequest(request);
      if (abortFunc != null) {
        _requestSubscriptions.putIfAbsent(
            request,
            () =>
                _cancellationStreamController.stream.listen((_) => abortFunc));

        if (_cancellationPending) {
          abortFunc.call();
          return completeRequest(request);
        }

        return Future.value();
      }

      throw UnsupportedError(
          '$CancellationToken does not support ${request.runtimeType}'
          ' as request');
    }

    throw CancellationTokenException('Token already disposed', this);
  }

  /// Marks a request as completed and eventually disposes the token
  ///
  /// You only have to call this, when you are manually working with `Request`'s
  /// yourself. Elsewise it is handled by `Client`.
  Future completeRequest(dynamic request) async {
    if (!isDisposed) {
      final subscription = _requestSubscriptions[request];
      if (subscription != null) {
        await subscription.cancel();
        _requestSubscriptions.remove(request);

        if (autoDispose && _requestSubscriptions.isEmpty) {
          return disposeToken();
        }

        return Future.value();
      }
    }
  }

  /// Disposes token
  Future disposeToken() async {
    if (!isDisposed) {
      _requestSubscriptions.clear();
      return _cancellationStreamController.close();
    }
  }
}
