// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

/// A record of debugging information about an HTTP request.
final class HttpClientRequestProfile {
  /// Whether HTTP profiling is enabled or not.
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
