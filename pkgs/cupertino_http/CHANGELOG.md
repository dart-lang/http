## 1.4.0

* **Experimental** support for the `package:web_socket` `WebSocket` interface.

## 1.3.0

* Use `package:http_image_provider` in the example application.
* Support `BaseResponseWithUrl`.

## 1.2.0

* Add support for setting additional http headers in
  `URLSessionConfiguration`.

## 1.1.0

* Add websocket support to `cupertino_api`.
* Add streaming upload support, i.e., if `CupertinoClient.send()` is called
  with a `StreamedRequest` then the data will be sent to the server
  incrementally.
* Deprecate `Data.fromUint8List` in favor of `Data.fromList`, which accepts
  any `List<int>`.
* Disable additional analyses for generated Objective-C bindings to prevent
  errors from `dart analyze`.
* Throw `ClientException` when the `'Content-Length'` header is invalid.
* Add support for configurable caching through
  `URLSessionConfiguration.cache`.

## 1.0.1

* Remove experimental status from "Readme"

## 1.0.0

* Require Dart 3.0
* Require Flutter 3.10.0

## 0.1.2

* Require Dart 2.19
* Fix a [reference count race with forwarded delegates](https://github.com/dart-lang/http/issues/887).

## 0.1.1

* Add a `URLSession.sessionDescription` field.

## 0.1.0

* Restructure `package:cupertino_http` to offer a single `import`.

## 0.0.11

* Fix a bug where the images in the example would be loaded using `dart:io`
  `HttpClient`.
* `CupertinoClient` throws an exception if `send` is called after `close`.

## 0.0.10

* Fix [Use of multiple CupertinoClients can result in cancelled requests](https://github.com/dart-lang/http/issues/826)

## 0.0.9

* Add a more complete implementation for `URLSessionTask`:
  * `priority` property - hint for host prioritization.
  * `currentRequest` property - the current request for the task (will be
    different than `originalRequest` in the face of redirects).
  * `originalRequest` property - the original request for the task. 
  * `error` property - an `Error` object if the request failed.
  * `taskDescription` property - a developer-set description of the task.
  * `countOfBytesExpectedToSend` property - the size of the body bytes that
    will be sent.
  * `countOfBytesSent` property - the number of body bytes sent in the request.
  * `prefersIncrementalDelivery` property - whether to deliver the response
    body in one chunk (if possible) or many.
* Upgrade to ffigen ^7.2.0 and remove unnecessary casts.

## 0.0.8

* Make timeout and caching policy configurable on a per-request basis.

## 0.0.7

* Upgrade `ffi` dependency.

## 0.0.6

* Make the number of simultaneous connections allowed to the same host
  configurable.
* Fixes
  [cupertino_http: Failure calling Dart_PostCObject_DL](https://github.com/dart-lang/http/issues/785).

## 0.0.5

* Add the ability to set network service type.
* Add the ability to control multipath TCP connections.
* Set `StreamedResponse.reasonPhrase` and `StreamedResponse.request`. 
  Fixes
  [cupertino_http: BaseResponse.request is null](https://github.com/dart-lang/http/issues/782).

## 0.0.4

* Add the ability to control caching policy.

## 0.0.3

* Follow the project style in the example app.
* Use `runWithClient` in the example app.
* Add another README example
 
## 0.0.2

* A single comment adjustment.

## 0.0.1

* Initial development release.
