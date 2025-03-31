[![pub package](https://img.shields.io/pub/v/http.svg)](https://pub.dev/packages/http)
[![package publisher](https://img.shields.io/pub/publisher/http.svg)](https://pub.dev/packages/http/publisher)

A composable, Future-based library for making HTTP requests.

This package contains a set of high-level functions and classes that make it
easy to consume HTTP resources. It's multi-platform (mobile, desktop, and
browser) and supports multiple implementations.

## Using

The easiest way to use this library is via the top-level functions. They allow
you to make individual HTTP requests with minimal hassle:

```dart
import 'package:http/http.dart' as http;

var url = Uri.https('example.com', 'whatsit/create');
var response = await http.post(url, body: {'name': 'doodle', 'color': 'blue'});
print('Response status: ${response.statusCode}');
print('Response body: ${response.body}');

print(await http.read(Uri.https('example.com', 'foobar.txt')));
```

> [!NOTE]
> Flutter applications may require
> [additional configuration](https://docs.flutter.dev/data-and-backend/networking#platform-notes)
> to make HTTP requests.

If you're making multiple requests to the same server, you can keep open a
persistent connection by using a [Client][] rather than making one-off requests.
If you do this, make sure to close the client when you're done:

```dart
var client = http.Client();
try {
  var response = await client.post(
      Uri.https('example.com', 'whatsit/create'),
      body: {'name': 'doodle', 'color': 'blue'});
  var decodedResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
  var uri = Uri.parse(decodedResponse['uri'] as String);
  print(await client.get(uri));
} finally {
  client.close();
}
```

> [!TIP]
> For detailed background information and practical usage examples, see:
> - [Dart Development: Fetch data from the internet](https://dart.dev/tutorials/server/fetch-data)
> - [Flutter Cookbook: Fetch data from the internet](https://docs.flutter.dev/cookbook/networking/fetch-data)
> - [The Flutter HTTP example application][flutterhttpexample]

You can also exert more fine-grained control over your requests and responses by
creating [Request][] or [StreamedRequest][] objects yourself and passing them to
[Client.send][].

[Request]: https://pub.dev/documentation/http/latest/http/Request-class.html
[StreamedRequest]: https://pub.dev/documentation/http/latest/http/StreamedRequest-class.html
[Client.send]: https://pub.dev/documentation/http/latest/http/Client/send.html

This package is designed to be composable. This makes it easy for external
libraries to work with one another to add behavior to it. Libraries wishing to
add behavior should create a subclass of [BaseClient][] that wraps another
[Client][] and adds the desired behavior:

[BaseClient]: https://pub.dev/documentation/http/latest/http/BaseClient-class.html
[Client]: https://pub.dev/documentation/http/latest/http/Client-class.html

```dart
class UserAgentClient extends http.BaseClient {
  final String userAgent;
  final http.Client _inner;

  UserAgentClient(this.userAgent, this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['user-agent'] = userAgent;
    return _inner.send(request);
  }
}
```

## Retrying requests

`package:http/retry.dart` provides a class [`RetryClient`][RetryClient] to wrap
an underlying [`http.Client`][Client] which transparently retries failing
requests.

[RetryClient]: https://pub.dev/documentation/http/latest/retry/RetryClient-class.html
[Client]: https://pub.dev/documentation/http/latest/http/Client-class.html

```dart
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

Future<void> main() async {
  final client = RetryClient(http.Client());
  try {
    print(await client.read(Uri.http('example.org', '')));
  } finally {
    client.close();
  }
}
```

By default, this retries any request whose response has status code 503
Temporary Failure up to three retries. It waits 500ms before the first retry,
and increases the delay by 1.5x each time. All of this can be customized using
the [`RetryClient()`][new RetryClient] constructor.

[new RetryClient]: https://pub.dev/documentation/http/latest/retry/RetryClient/RetryClient.html

## Choosing an implementation

There are multiple implementations of the `package:http` [`Client`][client] interface. By default, `package:http` uses [`BrowserClient`][browserclient] on the web and [`IOClient`][ioclient] on all other platforms. You can choose a different [`Client`][client] implementation based on the needs of your application.

You can change implementations without changing your application code, except
for a few lines of [configuration](#2-configure-the-http-client).

Some well-supported implementations are:

| Implementation | Supported Platforms | SDK | Caching | HTTP3/QUIC | Platform Native | 
| -------------- | ------------------- | ----| ------- | ---------- | --------------- |
| `package:http` — [`IOClient`][ioclient] | Android, iOS, Linux, macOS, Windows | Dart, Flutter | ❌ | ❌ | ❌ |
| `package:http` — [`BrowserClient`][browserclient] | Web | Dart, Flutter | ― | ✅︎ | ✅︎ | Dart, Flutter |
| [`package:cupertino_http`][cupertinohttp] — [`CupertinoClient`][cupertinoclient] | iOS, macOS | Flutter | ✅︎ | ✅︎ | ✅︎ |
| [`package:cronet_http`][cronethttp] — [`CronetClient`][cronetclient] | Android | Flutter | ✅︎ | ✅︎ | ― |
| [`package:fetch_client`][fetch] — [`FetchClient`][fetchclient] | Web | Dart, Flutter | ✅︎ | ✅︎ | ✅︎ |

> [!TIP]
> If you are writing a Dart package or Flutter plugin that uses
> `package:http`, you should not depend on a particular [`Client`][client]
> implementation. Let the application author decide what implementation is
> best for their project. You can make that easier by accepting an explicit
> [`Client`][client] argument. For example:
>
> ```dart
> Future<Album> fetchAlbum({Client? client}) async {
>   client ??= Client();
>   ...
> }
> ```

## Configuration

To use an HTTP client implementation other than the default, you must:
1. Add the HTTP client as a dependency.
2. Configure the HTTP client.
3. Connect the HTTP client to the code that uses it.

### 1. Add the HTTP client as a dependency.

To add a package compatible with the Dart SDK to your project, use `dart pub add`.

For example:

```terminal
# Replace  "fetch_client" with the package that you want to use.
dart pub add fetch_client
```

To add a package that requires the Flutter SDK, use `flutter pub add`.

For example:

```terminal
# Replace  "cupertino_http" with the package that you want to use.
flutter pub add cupertino_http
```

### 2. Configure the HTTP client.

Different `package:http` [`Client`][client] implementations may require
different configuration options.

Add a function that returns a correctly configured [`Client`][client]. You can
return a different [`Client`][client] on different platforms.

For example:

```dart
Client httpClient() {
  if (Platform.isAndroid) {
    final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: 1000000);
    return CronetClient.fromCronetEngine(engine);
  }
  if (Platform.isIOS || Platform.isMacOS) {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration()
      ..cache = URLCache.withCapacity(memoryCapacity: 1000000);
    return CupertinoClient.fromSessionConfiguration(config);
  }
  return IOClient();
}
```

> [!TIP]
> [The Flutter HTTP example application][flutterhttpexample] demonstrates
> configuration best practices.

#### Supporting browser and native

If your application can be run in the browser and natively, you must put your
browser and native configurations in separate files and import the correct file
based on the platform.

For example:

```dart
// -- http_client_factory.dart
Client httpClient() {
  if (Platform.isAndroid) {
    return CronetClient.defaultCronetEngine();
  }
  if (Platform.isIOS || Platform.isMacOS) {
    return CupertinoClient.defaultSessionConfiguration();
  }
  return IOClient();
}
```

```dart
// -- http_client_factory_web.dart
Client httpClient() => FetchClient();
```

```dart
// -- main.dart
import 'http_client_factory.dart'
    if (dart.library.js_interop) 'http_client_factory_web.dart'

// The correct `httpClient` will be available.
```

### 3. Connect the HTTP client to the code that uses it.

The best way to pass [`Client`][client] to the places that use it is
explicitly through arguments.

For example:

```dart
void main() {
  final client = httpClient();
  fetchAlbum(client, ...);
}
```

When using the Flutter SDK, you can use a one of many
[state management approaches][flutterstatemanagement].

> [!TIP]
> [The Flutter HTTP example application][flutterhttpexample] demonstrates
> how to make the configured [`Client`][client] available using
> [`package:provider`][provider] and
> [`package:http_image_provider`][http_image_provider].

When using the Dart SDK, you can use [`runWithClient`][runwithclient] to
ensure that the correct [`Client`][client] is used when explicit argument
passing is not an option. For example, if you depend on code that uses
top-level functions (e.g. `http.post`) or calls the
[`Client()`][clientconstructor] constructor. When an [Isolate][isolate] is
spawned, it does not inherit any variables from the calling Zone, so
`runWithClient` needs to be used in each Isolate that uses `package:http`.

You can ensure that only the `Client` that you have explicitly configured is
used by defining `no_default_http_client=true` in the environment. This will
also allow the default `Client` implementation to be removed, resulting in
a reduced application size.

```terminal
$ flutter build appbundle --dart-define=no_default_http_client=true ...
$ dart compile exe --define=no_default_http_client=true ...
```

[browserclient]: https://pub.dev/documentation/http/latest/browser_client/BrowserClient-class.html
[client]: https://pub.dev/documentation/http/latest/http/Client-class.html
[clientconstructor]: https://pub.dev/documentation/http/latest/http/Client/Client.html
[cupertinohttp]: https://pub.dev/packages/cupertino_http
[cupertinoclient]: https://pub.dev/documentation/cupertino_http/latest/cupertino_http/CupertinoClient-class.html
[cronethttp]: https://pub.dev/packages/cronet_http
[cronetclient]: https://pub.dev/documentation/cronet_http/latest/cronet_http/CronetClient-class.html
[fetch]: https://pub.dev/packages/fetch_client
[fetchclient]: https://pub.dev/documentation/fetch_client/latest/fetch_client/FetchClient-class.html
[flutterhttpexample]: https://github.com/dart-lang/http/tree/master/pkgs/flutter_http_example
[http_image_provider]: https://pub.dev/documentation/http_image_provider
[ioclient]: https://pub.dev/documentation/http/latest/io_client/IOClient-class.html
[isolate]: https://dart.dev/language/concurrency#how-isolates-work
[flutterstatemanagement]: https://docs.flutter.dev/data-and-backend/state-mgmt/options
[provider]: https://pub.dev/packages/provider
[runwithclient]: https://pub.dev/documentation/http/latest/http/runWithClient.html
