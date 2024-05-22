[![pub package](https://img.shields.io/pub/v/http_profile.svg)](https://pub.dev/packages/http_profile)
[![package publisher](https://img.shields.io/pub/publisher/http_profile.svg)](https://pub.dev/packages/http_profile/publisher)

A package that allows HTTP clients outside of the Dart SDK to integrate with
the DevTools Network View.

**NOTE:** This package is meant for developers *implementing* HTTP clients, not
developers *using* HTTP clients.

## Using

`HttpClientRequestProfile.profile` returns an `HttpClientRequestProfile` object
if HTTP profiling is enabled. Populating the fields of that object with
information about an HTTP request and about the response to that request will
make that information show up in the
[DevTools Network View](https://docs.flutter.dev/tools/devtools/network).

```dart
import 'package:http_profile/http_profile.dart';

Future<String> get(Uri uri) {
  final profile = HttpClientRequestProfile.profile(
    requestStartTime: DateTime.now(),
    requestMethod: 'GET',
    requestUri: uri.toString(),
  );
  profile?.connectionInfo = {
      'localPort': 1285,
      'remotePort': 443,
      'connectionPoolId': '21x23',
    };

  profile.requestData.proxyDetails = HttpProfileProxyData(
    host: 'https://www.example.com',
    username: 'abc123',
    isDirect: true,
    port: 4321,
  );

  // Make the HTTP request and populate the response data.

  profile.responseData.headersListValues = {
    'connection': ['keep-alive'],
    'cache-control': ['max-age=43200'],
    'content-type': ['application/json', 'charset=utf-8'],
  };

  return responseString;
}
```

Refer to the source of
[`package:cupertino_http`](https://github.com/dart-lang/http/blob/master/pkgs/cupertino_http/lib/src/cupertino_client.dart)
to see a comprehensive example of how `package:http_profile` can be integrated
into an HTTP client.

## Status: pre-1.0

**NOTE**: We are in the process of collecting feedback and iterating on this
package, so new versions that include API and breaking changes may be published
frequently.

Your feedback is valuable and will help us evolve this package. For general
feedback, suggestions, and comments, please file an issue in the
[bug tracker](https://github.com/dart-lang/http/issues).

