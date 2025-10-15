## 0.1.1-wip

- `OkHttpClient` now receives an `OkHttpClientConfiguration` to configure the client on a per-call basis.
- `OkHttpClient` supports setting four types of timeouts: [`connectTimeout`](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-ok-http-client/-builder/connect-timeout.html), [`readTimeout`](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-ok-http-client/-builder/read-timeout.html), [`writeTimeout`](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-ok-http-client/-builder/write-timeout.html), and [`callTimeout`](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-ok-http-client/-builder/call-timeout.html), using the `OkHttpClientConfiguration`.
- Upgrade to `jni` 0.14.0
- Upgrade to `jnigen` 0.14.0
- `OKHttpClient` supports client certificates.
- Support `package:web_socket` 1.0.0.
- Set `minSdk=24`.
- Add a missing call to `TrustManagerFactory.init`.

## 0.1.0

- Implementation of [`BaseClient`](https://pub.dev/documentation/http/latest/http/BaseClient-class.html) and `send()` method using [`enqueue()` API](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-call/enqueue.html)
- `ok_http` can now send asynchronous requests and stream response bodies.
- Add [DevTools Network View](https://docs.flutter.dev/tools/devtools/network) support.
- WebSockets support is now available in the `ok_http` package. Wraps around the OkHttp [WebSocket API](https://square.github.io/okhttp/5.x/okhttp/okhttp3/-web-socket/index.html).
