[![pub package](https://img.shields.io/pub/v/http_profile.svg)](https://pub.dev/packages/http_profile)
[![package publisher](https://img.shields.io/pub/publisher/http_profile.svg)](https://pub.dev/packages/http_profile/publisher)

A package that allows HTTP clients outside of the Dart SDK to integrate with
the DevTools Network tab.

## Using

`HttpClientRequestProfile.profile` returns an `HttpClientRequestProfile` object.
Populating the fields of that object with information about an HTTP request and
about the response to that request will make that information show up in the
DevTools Network tab.

```dart
import 'package:http_profile/http_profile.dart';

void main() {
  HttpClientRequestProfile.profilingEnabled = true;

  final profile = HttpClientRequestProfile.profile(
    requestStartTime: DateTime.parse('2024-03-21'),
    requestMethod: 'GET',
    requestUri: 'https://www.example.com',
  )!
    ..connectionInfo = {
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

  profile.responseData.headersListValues = {
    'connection': ['keep-alive'],
    'cache-control': ['max-age=43200'],
    'content-type': ['application/json', 'charset=utf-8'],
  };

  // ...

}
```

Refer to the source of
[`package:cupertino_http`](https://github.com/dart-lang/http/blob/master/pkgs/cupertino_http/lib/src/cupertino_client.dart)
to see a comprehensive example of how `package:http_profile` can be integrated
into an HTTP client.

## Status: experimental

**NOTE**: This package is currently experimental and published under the
[labs.dart.dev](https://dart.dev/dart-team-packages) pub publisher in order to
solicit feedback.

For packages in the labs.dart.dev publisher we generally plan to either graduate
the package into a supported publisher (dart.dev, tools.dart.dev) after a period
of feedback and iteration, or discontinue the package. These packages have a
much higher expected rate of API and breaking changes.

Your feedback is valuable and will help us evolve this package. For general
feedback, suggestions, and comments, please file an issue in the
[bug tracker](https://github.com/dart-lang/http/issues).

