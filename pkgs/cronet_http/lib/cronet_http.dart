// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// An Android Flutter plugin that provides access to the
/// [Cronet](https://developer.android.com/guide/topics/connectivity/cronet/reference/org/chromium/net/package-summary)
/// HTTP client.
///
/// ```
/// import 'package:cronet_http/cronet_http.dart';
///
/// void main() async {
///   var client = CronetClient.defaultCronetEngine();
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
///
/// [CronetClient] is an implementation of the `package:http` [Client],
/// which means that it can easily used conditionally based on the current
/// platform.
///
/// ```
/// void main() {
///   var clientFactory = Client.new; // Constructs the default client.
///   if (Platform.isAndroid) {
///     Future<CronetEngine>? engine;
///     clientFactory = () {
///       engine ??= CronetEngine.build(
///           cacheMode: CacheMode.memory, userAgent: 'MyAgent');
///       return CronetClient.fromCronetEngineFuture(engine!);
///     };
///   }
///   runWithClient(() => runApp(const MyFlutterApp()), clientFactory);
/// }
/// ```
///
/// After the above setup, calling [Client] methods or any of the
/// `package:http` convenient functions (e.g. [get]) will result in
/// [CronetClient] being used on Android.
library;

import 'package:http/http.dart';

import 'src/cronet_client.dart';

export 'src/cronet_client.dart';
