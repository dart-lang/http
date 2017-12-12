Middleware for the [`http`](https://pub.dartlang.org/packages/http) package that
transparently retries failing requests.

To use this, just create an [`RetryClient`][RetryClient] that wraps the
underlying [`http.Client`][Client]:

[RetryClient]: https://www.dartdocs.org/documentation/http_retry/latest/http_retry/RetryClient-class.html
[Client]: https://www.dartdocs.org/documentation/http/latest/http/Client-class.html

```dart
import 'package:http/http.dart' as http;
import 'package:http_retry/http_retry.dart';

main() async {
  var client = new RetryClient(new http.Client());
  print(await client.read("http://example.org"));
  await client.close();
}
```

By default, this retries any request whose response has status code 503
Temporary Failure up to three retries. It waits 500ms before the first retry,
and increases the delay by 1.5x each time. All of this can be customized using
the [`new RetryClient()`][new RetryClient] constructor.

[new RetryClient]: https://www.dartdocs.org/documentation/http_retry/latest/http_retry/RetryClient/RetryClient.html
