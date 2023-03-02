// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Provides access to the
/// [Foundation URL Loading System](https://developer.apple.com/documentation/foundation/url_loading_system).
///
/// # CupertinoClient
///
/// The most convenient way to `package:cupertino_http` it is through
/// [CupertinoClient].
///
/// ```
/// import 'package:cupertino_http/cupertino_http.dart';
///
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
///
/// [CupertinoClient] is an implementation of the `package:http` [Client],
/// which means that it can easily used conditionally based on the current
/// platform.
///
/// ```
/// void main() {
///   var clientFactory = Client.new; // The default Client.
///   if (Platform.isIOS || Platform.isMacOS) {
///     clientFactory = CupertinoClient.defaultSessionConfiguration.call;
///   }
///   runWithClient(() => runApp(const MyFlutterApp()), clientFactory);
/// }
/// ```
///
/// After the above setup, calling [Client] methods or any of the
/// `package:http` convenient functions (e.g. [get]) will result in
/// [CupertinoClient] being used on macOS and iOS.
///
/// # NSURLSession API
///
/// `package:cupertino_http` also allows direct access to the
/// [Foundation URL Loading System](https://developer.apple.com/documentation/foundation/url_loading_system)
/// APIs.
///
/// ```
/// void main() {
///   final url = Uri.https('www.example.com', '/');
///   final session = URLSession.sharedSession();
///   final task = session.dataTaskWithCompletionHandler(
///     URLRequest.fromUrl(url),
///       (data, response, error) {
///     if (error == null) {
///       if (response != null && response.statusCode == 200) {
///         print(response);  // Do something with the response.
///         return;
///       }
///     }
///     print(error);  // Handle errors.
///   });
///   task.resume();
/// }
/// ```
library;

import 'package:http/http.dart';

import 'src/cupertino_client.dart';

export 'src/cupertino_api.dart';
export 'src/cupertino_client.dart';
