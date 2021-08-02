import 'dart:async';

import 'base_request.dart';
import 'exception.dart';

typedef AbortFunc = void Function();

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

  /// If cancellation has been requested for token
  bool get isCancellationPending => _cancellationPending;

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

  /// Registers a request
  ///
  /// You only have to call this, when you are manually working with `Request`'s
  /// yourself. Elsewise it is handled by `Client`.
  Future registerRequest(AbortFunc requestAbort,
      {dynamic debugRequest, BaseRequest? baseRequest, Completer? completer}) {
    Future cancel() {
      //TODO: Debugging web abort()
      //print('Abort for ${baseRequest?.url} at ${debugRequest.readyState}');
      requestAbort.call();

      if (completer?.isCompleted == false) {
        completer!.completeError(
            ClientException('Request has been aborted', baseRequest?.url),
            StackTrace.current);
      }

      return completeRequest(requestAbort);
    }

    if (!isDisposed) {
      _requestSubscriptions.putIfAbsent(requestAbort,
          () => _cancellationStreamController.stream.listen((_) => cancel()));

      if (_cancellationPending) {
        return cancel();
      }

      return Future.value();
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
