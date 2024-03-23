## 1.2.0

* Support the Cronet embedding dependency with `--dart-define=cronetHttpNoPlay=true`.
* Fix a bug in the documentation where `isOwned` is used rather than
  `closeEngine`.
* Upgrade `package:jni` to 0.7.3 to fix a SIGSEGV caused by a null
  pointer dereference.

## 1.1.1

* Make it possible to construct `CronetClient` with custom a `CronetEngine`
  while still allowing `CronetClient` to close the `CronetEngine`.

## 1.1.0

* Use `package:http_image_provider` in the example application.
* Support Android API 21+.
* Support `BaseResponseWithUrl`.

## 1.0.0

* No functional changes. 

## 0.4.2

* Require `package:jni >= 0.7.2` to remove a potential buffer overflow.
* Fix a bug where incorrect HTTP request methods were sent.

## 0.4.1
 
* Require `package:jni >= 0.7.1` so that depending on `package:cronet_http` 
  does not break macOS builds.

* Fix obsolete `CronetClient()` constructor usage.

## 0.4.0
 
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
