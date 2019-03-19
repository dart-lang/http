A composable, Future-based library for making HTTP requests.

[![pub package](https://img.shields.io/pub/v/http.svg)](https://pub.dartlang.org/packages/http)
[![Build Status](https://travis-ci.org/dart-lang/http.svg?branch=master)](https://travis-ci.org/dart-lang/http)

This package contains a set of high-level functions and classes that make it
easy to consume HTTP resources. It's platform-independent, and can be used on
both the command-line and the browser.

## Using

The easiest way to use this library is via the top-level functions. They allow
you to make individual HTTP requests with minimal hassle:

```dart
import 'package:http/http.dart' as http;

var url = 'http://example.com/whatsit/create';
var response = await http.post(url, body: {'name': 'doodle', 'color': 'blue'});
print('Response status: ${response.statusCode}');
print('Response body: ${response.body}');

print(await http.read('http://example.com/foobar.txt'));
```

If you're making multiple requests to the same server, you can keep open a
persistent connection by using a [Client][] rather than making one-off requests.
If you do this, make sure to close the client when you're done:

```dart
var client = new http.Client();
try {
  var uriResponse = await client.post('http://example.com/whatsit/create',
      body: {'name': 'doodle', 'color': 'blue'});
  print(await client.get(uriResponse.bodyFields['uri']));
} finally {
  client.close();
}
```

You can also exert more fine-grained control over your requests and responses by
creating [Request][] or [StreamedRequest][] objects yourself and passing them to
[Client.send][].

[Request]: https://pub.dartlang.org/documentation/http/latest/http/Request-class.html
[StreamedRequest]: https://pub.dartlang.org/documentation/http/latest/http/StreamedRequest-class.html
[Client.send]: https://pub.dartlang.org/documentation/http/latest/http/Client/send.html

This package is designed to be composable. This makes it easy for external
libraries to work with one another to add behavior to it. Libraries wishing to
add behavior should create a subclass of [BaseClient][] that wraps another
[Client][] and adds the desired behavior:

[BaseClient]: https://pub.dartlang.org/documentation/http/latest/http/BaseClient-class.html
[Client]: https://pub.dartlang.org/documentation/http/latest/http/Client-class.html

```dart
class UserAgentClient extends http.BaseClient {
  final String userAgent;
  final http.Client _inner;

  UserAgentClient(this.userAgent, this._inner);

  Future<StreamedResponse> send(BaseRequest request) {
    request.headers['user-agent'] = userAgent;
    return _inner.send(request);
  }
}
```
## Using on the Browser
The HTTP library can be used on the browser via the BrowserClient class in package:http/browser_client.dart. This client translates requests into XMLHttpRequests. For example:

```dart
import 'dart:async';
import 'package:http/browser_client.dart';

main() async {
  var client = new BrowserClient();
  var url = '/whatsit/create';
  var response =
      await client.post(url, body: {'name': 'doodle', 'color': 'blue'});
  print('Response status: ${response.statusCode}');
  print('Response body: ${response.body}');
}
```

## Using in Flutter
Note that when using this library in Flutter, your app needs to have Internet permissions. In iOS, this should already exist, but in Android, you will need to add the Internet Permission to your AndroidManifest.xml. By default, Flutter includes this permission in `android/app/src/` but that only applies to debug builds. For release builds, you will also need to specify Internet permissions in the file `android/app/src/main/AndroidManifest.xml` like so:

```xml
<android>
  <uses-permission android:name="android.permission.INTERNET" />
</android>
```

