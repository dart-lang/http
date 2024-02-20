[![pub package](https://img.shields.io/pub/v/web_socket_conformance_tests.svg)](https://pub.dev/packages/web_socket_conformance_tests)

A library that tests whether implementations of `package:web_socket`
`WebSocket` behave as expected.

This package is intended to be used in the tests of packages that implement
`package:web_socket` `Socket`.

The tests work by starting a series of test servers and running the provided
`package:web_socket` `WebSocket` against them.

## Usage

`package:web_socket_conformance_tests` is meant to be used in the tests suite
of a `package:web_socket` `WebSocket` like:

```dart
import 'package:web_socket/web_socket.dart';
import 'package:test/test.dart';

import 'package:web_socket_conformance_tests/web_socket_conformance_tests.dart';

class MyWebSocket implements WebSocket {
  // Your implementation here.
}

void main() {
  group('WebSocket conformance tests', () {
    testAll(MyWebSocket());
  });
}
```

**Note**: This package does not have it's own tests, instead it is
exercised by the tests in `package:web_socket`.
