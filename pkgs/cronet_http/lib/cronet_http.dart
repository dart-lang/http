// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// An Android Flutter plugin that provides access to the
/// [Cronet](https://developer.android.com/guide/topics/connectivity/cronet/reference/org/chromium/net/package-summary)
/// HTTP client.
///
/// The platform interface must be initialized before using this plugin e.g. by
/// calling
/// [`WidgetsFlutterBinding.ensureInitialized`](https://api.flutter.dev/flutter/widgets/WidgetsFlutterBinding/ensureInitialized.html)
/// or
/// [`runApp`](https://api.flutter.dev/flutter/widgets/runApp.html).
///
/// [CronetClient] is an implementation of the `package:http` [Client],
/// which means that it can easily used conditionally based on the current
/// platform.
///
/// ```
/// import 'package:provider/provider.dart';
///
/// void main() {
///   final Client httpClient;
///   if (Platform.isAndroid) {
///     // `package:cronet_http` cannot be used until
///     // `WidgetsFlutterBinding.ensureInitialized()` or `runApp` is called.
///     WidgetsFlutterBinding.ensureInitialized();
///     final engine = CronetEngine.build(
///         cacheMode: CacheMode.memory,
///         cacheMaxSize: 2 * 1024 * 1024,
///         userAgent: 'Book Agent');
///     httpClient = CronetClient.fromCronetEngine(engine, closeEngine: true);
///   } else {
///     httpClient = IOClient(HttpClient()..userAgent = 'Book Agent');
///   }
///
///   runApp(Provider<Client>(
///       create: (_) => httpClient,
///       child: const BookSearchApp(),
///       dispose: (_, client) => client.close()));
///   }
/// }
/// ```
library;

import 'package:http/http.dart';

import 'src/cronet_client.dart';

export 'src/cronet_client.dart';
