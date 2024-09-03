# flutter_http_example

A Flutter sample app that illustrates how to configure and use
[`package:http`](https://pub.dev/packages/http).

## Goals for this sample

* Provide you with example code for using `package:http` in Flutter,
  including:

    * configuration for multiple platforms.
    * using `package:provider` to pass `Client`s through an application.
    * writing tests using `MockClient`.

## The important bits

### `http_client_factory.dart`

This library used to create `package:http` `Client`s when the app is run inside
the Dart virtual machine, meaning all platforms except the web browser.

### `http_client_factory_web.dart`

This library used to create `package:http` `Client`s when the app is run inside
a web browser.

Web configuration must be done in a separate library because Dart code cannot
import `dart:ffi` or `dart:io` when run in a web browser.

### `main.dart`

This library demonstrates how to:

* import `http_client_factory.dart` or `http_client_factory_web.dart`,
  depending on whether we are targeting the web browser or not.
* share a `package:http` `Client` by using `package:provider`.
* call `package:http` `Client` methods.

### `widget_test.dart`

This library demonstrates how to construct tests using `MockClient`.
