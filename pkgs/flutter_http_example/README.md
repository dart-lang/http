# flutter_http_example

A Flutter sample app that illustrates how to configure and use
[`package:http`](https://pub.dev/packages/http).

## Goals for this sample

* Provide you with example code for using `package:http` in Flutter,
  including configuration for multiple platforms.

## The important bits

### `http_client_factory.dart`

This file used to create `package:http` `Client`s when the app is run inside
the Dart virtual machine, meaning all platforms except the web browser.

### `http_client_factory_web.dart`

This file used to create `package:http` `Client`s when the app is run inside
a web browser.

Web configuration must be done in a seperate file because Dart code cannot
import `dart:ffi` or `dart:io` when run in a web browser.

### `main.dart`

This file demonstrates how to:

* import `http_client_factory.dart` or `http_client_factory_web.dart`,
  depending on whether we are targeting the web browser or not.
* call `package:http` functions.
