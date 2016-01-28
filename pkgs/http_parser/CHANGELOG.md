## 2.1.0

* Added `WebSocketChannel`, an implementation of `StreamChannel` that's backed
  by a `WebSocket`.

* Deprecated `CompatibleWebSocket` in favor of `WebSocketChannel`.

## 2.0.0

* Removed the `DataUri` class. It's redundant with the `Uri.data` getter that's
  coming in Dart 1.14, and the `DataUri.data` field in particular was an invalid
  override of that field.

## 1.1.0

* The MIME spec says that media types and their parameter names are
  case-insensitive. Accordingly, `MediaType` now uses a case-insensitive map for
  its parameters and its `type` and `subtype` fields are now always lowercase.

## 1.0.0

This is 1.0.0 because the API is stable—there are no breaking changes.

* Added an `AuthenticationChallenge` class for parsing and representing the
  value of `WWW-Authenticate` and related headers.

* Added a `CaseInsensitiveMap` class for representing case-insensitive HTTP
  values.

## 0.0.2+8

* Bring in the latest `dart:io` WebSocket code.

## 0.0.2+7

* Add more detail to the readme.

## 0.0.2+6

* Updated homepage URL.

## 0.0.2+5

* Widen the version constraint on the `collection` package.

## 0.0.2+4

* Widen the `string_scanner` version constraint.

## 0.0.2+3

* Fix a library name conflict.

## 0.0.2+2

* Fixes for HTTP date formatting.

## 0.0.2+1

* Minor code refactoring.

## 0.0.2

* Added `CompatibleWebSocket`, for platform- and API-independent support for the
  WebSocket API.
