## 0.4.0-jni
 
* Use more efficient operations when copying bytes between Java and Dart.

## 0.3.0-jni

* Switch to using `package:jnigen` for bindings to Cronet
* Support for running in background isolates.
* **Breaking Change:** `CronetEngine.build()` returns a `CronetEngine` rather
  than a `Future<CronetEngine>` and `CronetClient.fromCronetEngineFuture()`
  has been removed because it is no longer necessary.

## 0.2.2

* Require Dart 3.0
* Throw `ClientException` when the `'Content-Length'` header is invalid.

## 0.2.1

* Require Dart 2.19
* Support `package:http` 1.0.0

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
