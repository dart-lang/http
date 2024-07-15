## 0.1.0

- Implementation of [`BaseClient`](https://pub.dev/documentation/http/latest/http/BaseClient-class.html) and `send()` method using [`enqueue()` API](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-call/enqueue.html)
- `ok_http` can now send asynchronous requests and stream response bodies.
- Add [DevTools Network View](https://docs.flutter.dev/tools/devtools/network) support.
- WebSockets support is now available in the `ok_http` package. Wraps around the OkHttp [WebSocket API](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-web-socket/index.html).
