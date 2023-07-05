import 'dart:async';

import 'package:meta/meta.dart';

import '../http.dart';
import 'active_request_tracker.dart';

/// Represents the state of a request that is in progress.
enum RequestLifecycleState {
  /// A connection is being opened to the server to send the request.
  connecting,

  /// The request data is being sent to the server.
  sending,

  /// The response is being received from the server.
  receiving,
}

/// Encapsulates timeouts for individual parts of a request's lifecycle.
class PartialTimeouts {
  /// The duration to wait for a connection to be successfully opened with a
  /// server before aborting the request.
  final Duration? connectTimeout;

  /// The duration to wait for the request data to be sent to the server before
  /// aborting the request.
  final Duration? sendTimeout;

  /// The duration to wait for a response to be received from the server
  /// before aborting the request.
  final Duration? receiveTimeout;

  /// Creates a new [PartialTimeouts].
  const PartialTimeouts({
    this.connectTimeout,
    this.sendTimeout,
    this.receiveTimeout,
  });

  /// Creates a new [PartialTimeouts] with all timeouts set to the
  /// specified [timeout].
  const PartialTimeouts.all(Duration timeout)
      : connectTimeout = timeout,
        sendTimeout = timeout,
        receiveTimeout = timeout;

  /// Returns true if a timeout is specified for the specified [state].
  /// Returns false otherwise.
  bool hasForState(RequestLifecycleState state) => forState(state) != null;

  /// Returns the timeout for the specified [state] if there is one specified,
  /// otherwise returns null.
  Duration? forState(RequestLifecycleState state) {
    switch (state) {
      case RequestLifecycleState.connecting:
        return connectTimeout;
      case RequestLifecycleState.sending:
        return sendTimeout;
      case RequestLifecycleState.receiving:
        return receiveTimeout;
    }
  }
}

/// A [RequestController] manages the lifecycle of a request, or multiple
/// requests.
///
/// Its primary purpose is to allow the proper cancellation of requests on
/// demand. This is useful for cases where a request is no longer needed, but
/// the response is still being awaited. Calling [cancel] on the controller
/// allows the library to clean up any resources associated with the request,
/// and to ensure that the response is never delivered.
///
/// It is perfectly valid to register one controller per request if individual
/// control over each request is desired. If you intend to call [cancel]
/// on a controller, ensure the controller is only registered on requests that
/// are intended to be cancelled together.
class RequestController {
  /// The timeout for the entire round trip of a request before it is aborted.
  ///
  /// If the request as a whole takes longer than this timeout, it will be
  /// cancelled.
  /// If this value is `null`, requests will never timeout.
  ///
  /// If a request times out, it will throw a [TimeoutException].
  final Duration? timeout;

  final PartialTimeouts? _lifecycleTimeouts;

  final List<ActiveRequestTracker> _activeRequests = [];

  /// Returns true if this controller has any timeouts specified.
  bool get hasTimeouts => timeout != null || hasLifecycleTimeouts;

  /// Returns true if this controller has any timeouts specified for individual
  /// parts of a request's lifecycle.
  bool get hasLifecycleTimeouts => _lifecycleTimeouts != null;

  /// Returns true if a timeout is specified for the specified request
  /// lifecycle [state].
  ///
  /// This is true if the timeout has been specified in the
  /// `partialTimeouts` parameter of the constructor for more granular control
  /// over timeouts.
  bool hasTimeoutForLifecycleState(RequestLifecycleState state) =>
      timeoutForLifecycleState(state) != null;

  /// Returns the timeout for the specified request lifecycle [state] if there
  /// is one specified, otherwise returns null.
  ///
  /// This is the timeout specified in the `partialTimeouts` parameter of the
  /// constructor for more granular control over timeouts.
  ///
  /// If no timeout is specified for the specified [state], this will return
  /// null.
  Duration? timeoutForLifecycleState(RequestLifecycleState state) =>
      _lifecycleTimeouts?.forState(state);

  /// Creates a new [RequestController].
  ///
  /// Optionally, a default [timeout] may be specified for requests on this
  /// controller. If no timeout is specified, requests will never timeout.
  /// See [timeout] for more details.
  ///
  /// For more granular control over timeouts, [partialTimeouts] may be
  /// specified in addition to, or instead of, [timeout]. These can be used
  /// to control the timeout for individual parts of a request's lifecycle.
  ///
  /// For instance, you may wish to abort a request if it takes too long to
  /// connect, but once it has connected, you may wish to allow the request
  /// to take as long as it needs to send and receive data.
  RequestController({this.timeout, PartialTimeouts? partialTimeouts})
      : _lifecycleTimeouts = partialTimeouts;

  /// Tracks a request with this controller.
  ///
  /// This method is called internally when a request is sent. It should not
  /// be called directly. A [StateError] will be thrown if the request is not
  /// bound to this controller.
  ///
  /// If the request is already being tracked by this controller, the
  /// existing [ActiveRequestTracker] will be returned.
  @internal
  ActiveRequestTracker track(BaseRequest request, {required bool isStreaming}) {
    if (request.controller != this) {
      throw StateError('Request is not bound to this controller');
    }

    if (_activeRequests.any((r) => r.request == request)) {
      return _activeRequests.firstWhere((r) => r.request == request);
    }

    final activeRequest =
        ActiveRequestTracker(request, isStreaming: isStreaming);
    _activeRequests.add(activeRequest);
    return activeRequest;
  }

  // Fetches a tracker for an existing request.
  @internal
  ActiveRequestTracker? getExistingTracker(BaseRequest request) =>
      _activeRequests.where((r) => r.request == request).singleOrNull;

  /// Cancels/aborts all pending requests on this controller.
  /// This will cause all requests to throw a [CancelledException].
  ///
  /// Optionally, a [message] may be specified to provide a reason for the
  /// cancellation that will be included in the exception. If no message is
  /// specified, the default message is "Request cancelled".
  void cancel([final String message = 'Request cancelled']) {
    for (final activeRequest in _activeRequests) {
      activeRequest.cancel(message);
    }
  }
}
