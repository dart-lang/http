## 0.2.1-dev

* Require Dart 2.19

## 0.2.0

* Restructure `package:cronet_http` to offer a
  `package:cronet_http/cronet_http.dart` import.

## 0.1.2

* Fix a NPE that occurs when an error occurs before a response is received.

## 0.1.1

* `CronetClient` throws an exception if `send` is called after `close`.

## 0.1.0

* Add a CronetClient that accepts a `Future<CronetEngine>`.
* Modify the example application to create a `CronetClient` using a
  `Future<CronetEngine>`.

## 0.0.4

* Fix a bug where the example would not use the configured `package:http`
  `Client` for Books API calls in some circumstances.
* Fix a bug where the images in the example would be loaded using `dart:io`
  `HttpClient`.

## 0.0.3

* Fix
  [contentLength property is not sent for streamed responses](https://github.com/dart-lang/http/issues/801)

## 0.0.2

* Set `StreamedResponse.reasonPhrase` and `StreamedResponse.request`. 

## 0.0.1

* Initial development release.
