[![pub package](https://img.shields.io/pub/v/cronet_http.svg)](https://pub.dev/packages/cronet_http)
[![package publisher](https://img.shields.io/pub/publisher/cronet_http.svg)](https://pub.dev/packages/cronet_http/publisher)

An Android Flutter plugin that provides access to the
[Cronet][]
HTTP client.

Cronet is available as part of
[Google Play Services][]. 

This package depends on [Google Play Services][] for its [Cronet][]
implementation.
[`package:cronet_http_embedded`](https://pub.dev/packages/cronet_http_embedded)
is functionally identical to this package but embeds [Cronet][] directly
instead of relying on [Google Play Services][].

## Motivation

Using [Cronet][], rather than the socket-based [dart:io HttpClient][]
implemententation, has several advantages:

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
  late Client httpClient;
  if (Platform.isAndroid) {
    final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: 2 * 1024 * 1024,
        userAgent: 'Book Agent');
    httpClient = CronetClient.fromCronetEngine(engine);
  } else {
    httpClient = IOClient(HttpClient()..userAgent = 'Book Agent');
  }

  final response = await client.get(Uri.https(
      'www.googleapis.com',
      '/books/v1/volumes',
      {'q': 'HTTP', 'maxResults': '40', 'printType': 'books'}));
}
```

[Cronet]: https://developer.android.com/guide/topics/connectivity/cronet/reference/org/chromium/net/package-summary
[dart:io HttpClient]: https://api.dart.dev/stable/dart-io/HttpClient-class.html
[Google Play Services]: https://developers.google.com/android/guides/overview
[package:http Client]: https://pub.dev/documentation/http/latest/http/Client-class.html
