## 0.11.3+13

* remove boundary characters that package:http_parser cannot parse.

## 0.11.3+12

* Don't quote the boundary header for `MultipartRequest`. This is more
  compatible with server quirks.

## 0.11.3+11

* Fix the SDK constraint to only include SDK versions that support importing
  `dart:io` everywhere.

## 0.11.3+10

* Stop using `dart:mirrors`.

## 0.11.3+9

* Remove an extra newline in multipart chunks.

## 0.11.3+8

* Properly specify `Content-Transfer-Encoding` for multipart chunks.

## 0.11.3+7

* Declare compatibility with `http_parser` 3.0.0.

## 0.11.3+6

* Fix one more strong mode warning in `http/testing.dart`.

## 0.11.3+5

* Fix some lingering strong mode warnings.

## 0.11.3+4

* Fix all strong mode warnings.

## 0.11.3+3

* Support `http_parser` 2.0.0.

## 0.11.3+2

* Require Dart SDK >= 1.9.0

* Eliminate many uses of `Chain.track` from the `stack_trace` package.

## 0.11.3+1

* Support `http_parser` 1.0.0.

## 0.11.3

* Add a `Client.patch` shortcut method and a matching top-level `patch` method.

## 0.11.2

* Add a `BrowserClient.withCredentials` property.

## 0.11.1+3

* Properly namespace an internal library name.

## 0.11.1+2

* Widen the version constraint on `unittest`.

## 0.11.1+1

* Widen the version constraint for `stack_trace`.

## 0.11.1

* Expose the `IOClient` class which wraps a `dart:io` `HttpClient`.

## 0.11.0+1

* Fix a bug in handling errors in decoding XMLHttpRequest responses for
  `BrowserClient`.

## 0.11.0

* The package no longer depends on `dart:io`. The `BrowserClient` class in
  `package:http/browser_client.dart` can now be used to make requests on the
  browser.

* Change `MultipartFile.contentType` from `dart:io`'s `ContentType` type to
  `http_parser`'s `MediaType` type.

* Exceptions are now of type `ClientException` rather than `dart:io`'s
  `HttpException`.

## 0.10.0

* Make `BaseRequest.contentLength` and `BaseResponse.contentLength` use `null`
  to indicate an unknown content length rather than -1.

* The `contentLength` parameter to `new BaseResponse` is now named rather than
  positional.

* Make request headers case-insensitive.

* Make `MultipartRequest` more closely adhere to browsers' encoding conventions.
