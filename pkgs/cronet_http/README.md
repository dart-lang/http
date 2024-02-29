[![pub package](https://img.shields.io/pub/v/cronet_http.svg)](https://pub.dev/packages/cronet_http)
[![package publisher](https://img.shields.io/pub/publisher/cronet_http.svg)](https://pub.dev/packages/cronet_http/publisher)

An Android Flutter plugin that provides access to the
[Cronet][] HTTP client.

Cronet is available as part of [Google Play Services][]
and as [a standalone embedded library][].

This package depends on [Google Play Services][]
for its [Cronet][] implementation.
To use the embedded version of [Cronet][] without [Google Play Services][],
see [Use embedded Cronet](#use-embedded-cronet).

## Motivation

Using [Cronet][], rather than the socket-based
[dart:io HttpClient][] implementation, has several advantages:

1. It automatically supports Android platform features such as HTTP proxies.
2. It supports configurable caching.
3. It supports more HTTP features such as HTTP/3.

## Using

The easiest way to use this library is via the the high-level interface
defined by [package:http Client][].

This approach allows the same HTTP code to be used on all platforms, while
still allowing platform-specific setup.

```dart
import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

void main() async {
  final Client httpClient;
  if (Platform.isAndroid) {
    final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: 2 * 1024 * 1024,
        userAgent: 'Book Agent');
    httpClient = CronetClient.fromCronetEngine(engine, closeEngine: true);
  } else {
    httpClient = IOClient(HttpClient()..userAgent = 'Book Agent');
  }

  final response = await client.get(
    Uri.https(
      'www.googleapis.com',
      '/books/v1/volumes',
      {'q': 'HTTP', 'maxResults': '40', 'printType': 'books'},
    ),
  );
  httpClient.close();
}
```

### Use embedded Cronet

If you want your application to work without [Google Play Services][],
you can instead depend on the `org.chromium.net:cronet-embedded` package
by using `dart-define` to set `cronetHttpNoPlay` is set to `true`.

For example:

```
flutter run --dart-define=cronetHttpNoPlay=true
```

To use the embedded version in `flutter test`:

```
flutter test --dart-define=cronetHttpNoPlay=true
```

[Cronet]: https://developer.android.com/guide/topics/connectivity/cronet/reference/org/chromium/net/package-summary
[Google Play Services]: https://developers.google.com/android/guides/overview
[a standalone embedded library]: https://mvnrepository.com/artifact/org.chromium.net/cronet-embedded
[dart:io HttpClient]: https://api.dart.dev/stable/dart-io/HttpClient-class.html
[package:http Client]: https://pub.dev/documentation/http/latest/http/Client-class.html
