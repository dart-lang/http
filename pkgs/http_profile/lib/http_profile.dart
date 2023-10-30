import 'dart:io';

/// Records information about an HTTP request.
final class HttpClientRequestProfile {
  /// Determines whether HTTP profiling is enabled or not.
  ///
  /// The value can be changed programmatically or through the DevTools Network
  /// UX.
  static bool get profilingEnabled => HttpClient.enableTimelineLogging;
  static set profilingEnabled(bool enabled) =>
      HttpClient.enableTimelineLogging = enabled;

  String? requestMethod;
  String? requestUri;

  HttpClientRequestProfile._();

  /// If HTTP profiling is enabled, returns
  /// a [HttpClientRequestProfile] otherwise returns `null`.
  static HttpClientRequestProfile? profile() {
    // Always return `null` in product mode so that the
    // profiling code can be tree shaken away.
    if (const bool.fromEnvironment('dart.vm.product') || !profilingEnabled) {
      return null;
    }
    final requestProfile = HttpClientRequestProfile._();
    return requestProfile;
  }
}
