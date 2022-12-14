## 0.0.4

* Fix a bug where the example would not use the configured `package:http`
  `Client` for Books API calls in some circumstances.
* Fix a bug where the images would be loaded using `dart:io` `HttpClient`.

## 0.0.3

* Fix
  [contentLength property is not sent for streamed responses](https://github.com/dart-lang/http/issues/801)

## 0.0.2

* Set `StreamedResponse.reasonPhrase` and `StreamedResponse.request`. 

## 0.0.1

* Initial development release.
