[![pub package](https://img.shields.io/pub/v/http_client_conformance_tests.svg)](https://pub.dev/packages/http_client_conformance_tests)

A library that tests whether implementations of `package:http`
[`Client`](https://pub.dev/documentation/http/latest/http/Client-class.html)
behave as expected.

This package is intended to be used in the tests of packages that implement
`package:http`
[`Client`](https://pub.dev/documentation/http/latest/http/Client-class.html).

The tests work by starting a series of test servers and running the provided
`package:http`
[`Client`](https://pub.dev/documentation/http/latest/http/Client-class.html)
against them.

## Usage

`package:http_client_conformance_tests` is meant to be used in the tests suite
of a `package:http`
[`Client`](https://pub.dev/documentation/http/latest/http/Client-class.html)
like:

```dart
import 'package:http/http.dart';
import 'package:test/test.dart';

import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';

class MyHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // Your implementation here.
  }
}

void main() {
  group('client conformance tests', () {
    testAll(MyHttpClient());
  });
}
```

**Note**: This package does not have it's own tests, instead it is
exercised by the tests in `package:http`.
