import 'dart:async';

import 'package:meta/meta.dart';

import 'base_request.dart';
import 'exception.dart';
import 'request_controller.dart';

/// Used internally to track a request's lifecycle, if a tracker exists for the
/// request (as specified in the [tracker] parameter). Otherwise returns the
/// original [future].
///
/// Used for more concise code in client implementations that track the
/// lifecycle.
///
/// See [RequestController] for the public API.
@internal
Future<T> maybeTrack<T>(
  final Future<T> future, {
  final ActiveRequestTracker? tracker,
  final RequestLifecycleState? state,
  void Function(Exception?)? onCancel,
}) {
  if (tracker != null) {
    return tracker.trackRequestState(
      future,
      state: state,
      onCancel: onCancel,
    );
  } else {
    return future;
  }
}

/// Used internally to track a request's lifecycle.
/// See [RequestController] for the public API.
@internal
class ActiveRequestTracker {
  final BaseRequest request;

  /// Whether the [ActiveRequestTracker] is tracking a streaming request.
  /// The response timeout can only be handled internally for non-streaming
  /// requests.
  /// This signals to any clients that want to buffer the response that they
  /// should track the response timeout themselves.
  final bool isStreaming;

  final List<Completer<void>> _pendingRequestActions = [];

  ActiveRequestTracker(
    this.request, {
    required this.isStreaming,
  });

  RequestController get controller => request.controller!;

  /// Whether the request is still in progress.
  bool _inProgress = true;

  bool get inProgress => _inProgress;

  Future<T> trackRequestState<T>(
    final Future<T> future, {
    final RequestLifecycleState? state,
    void Function(Exception?)? onCancel,
  }) {
    // If the request is not being processed, simply ignore any tracking.
    if (!_inProgress) {
      return future;
    }

    // Create a completer to track the request (and allow it to be cancelled).
    final pendingRequestAction = Completer<T>();
    _pendingRequestActions.add(pendingRequestAction);

    // Return a future that tracks both; completing or error-ing with the
    // result of the first one to complete. This means if
    // [pendingRequestAction] is cancelled first, [future] will be discarded.
    // If [future] completes first, [pendingRequestAction] will be discarded.
    var cancellable = Future.any([pendingRequestAction.future, future]);

    // If a timeout is specified for this state, apply it to the cancellable
    // future.
    if (state != null && controller.hasTimeoutForLifecycleState(state)) {
      cancellable =
          cancellable.timeout(controller.timeoutForLifecycleState(state)!);
    }

    cancellable
      // Handle timeouts by simply calling [onCancel] and rethrowing the
      // timeout exception.
      ..onError<TimeoutException>(
        (error, stackTrace) {
          onCancel?.call(error);
          throw error;
        },
      )
      // Similarly, handle cancellations by calling [onCancel] and rethrowing
      // the cancellation exception.
      ..onError<CancelledException>(
        (error, stackTrace) {
          onCancel?.call(error);
          throw error;
        },
      )
      // When the cancellable future completes, remove the pending request from
      // the list of pending requests.
      ..whenComplete(
        () => _pendingRequestActions.remove(pendingRequestAction),
      );

    return cancellable;
  }

  /// Cancels the request by expiring all pending request actions.
  void cancel([final String message = 'Request cancelled']) {
    _inProgress = false;

    for (final pendingAction in _pendingRequestActions) {
      pendingAction.completeError(CancelledException(message));
    }
  }
}
