## 2.0.2

* Fix a dependency that was incorrectly marked as dev-only.

## 2.0.1

* Fix most strong mode errors and warnings.

## 2.0.0

* **Breaking:** Change the signature of `HttpMultiServer.loopbackSecure()` to
  match the new Dart 1.13 `HttpServer.bindSecure()` signature. This removes the
  `certificateName` named parameter and adds the required `context` parameter
  and the named `v6Only` and `shared` parameters.

* Added `v6Only` and `shared` parameters to `HttpMultiServer.loopback()` to
  match `HttpServer.bind()`.

## 1.3.2

* Eventually stop retrying port allocation if it fails repeatedly.

* Properly detect socket errors caused by already-in-use addresses.

## 1.3.1

* `loopback()` and `loopbackSecure()` recover gracefully if an ephemeral port is
  requested and the located port isn't available on both IPv4 and IPv6.

## 1.3.0

* Add support for `HttpServer.autoCompress`.

## 1.2.0

* Add support for `HttpServer.defaultResponseHeaders.clear`.

* Fix `HttpServer.defaultResponseHeaders.remove` and `.removeAll`.

## 1.1.0

* Add support for `HttpServer.defaultResponseHeaders`.

## 1.0.2

* Remove the workaround for [issue 19815][].

## 1.0.1

* Ignore errors from one of the servers if others are still bound. In
  particular, this works around [issue 19815][] on some Windows machines where
  IPv6 failure isn't discovered until we try to connect to the socket.

[issue 19815]: http://code.google.com/p/dart/issues/detail?id=19815
