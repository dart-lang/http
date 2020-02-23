Middleware for the [`http`](https://pub.dev/packages/http) package that
transparently retries failing requests.

To use this, just create an [`RetryClient`][RetryClient] that wraps the
underlying [`http.Client`][Client]:

[RetryClient]: https://pub.dev/documentation/http_retry/latest/http_retry/RetryClient-class.html
[Client]: https://pub.dev/documentation/http/latest/http/Client-class.html

```dart
import 'package:http/http.dart' as http;
import 'package:http_retry/http_retry.dart';

Future<void> main() async {
  final client = RetryClient(http.Client());
  try {
    print(await client.read('http://example.org'));
  } finally {
    client.close();
  }
}
```

By default, this retries any request whose response has status code 503
Temporary Failure up to three retries. It waits 500ms before the first retry,
and increases the delay by 1.5x each time. All of this can be customized using
the [`RetryClient()`][new RetryClient] constructor.

[new RetryClient]: https://pub.dev/documentation/http_retry/latest/http_retry/RetryClient/RetryClient.html
