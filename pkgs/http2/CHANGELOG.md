# Changelog

## 0.1.7

* Fixes for Dart 2.0.

## 0.1.6

* Strong mode fixes and other cleanup.

## 0.1.5

* Removed use of new `Function` syntax, since it isn't fully supported in Dart
  1.24.

## 0.1.4

* Added an `onActiveStateChanged` callback to `Connection`, which is invoked when
  the connection changes state from idle to active or from active to idle. This
  can be used to implement an idle connection timeout.

## 0.1.3

* Fixed a bug where a closed window would not open correctly due to an increase
  in initial window size.

## 0.1.2

* The endStream bit is now set on the requested frame, instead of on an empty
  data frame following it.
* Added an `onTerminated` hook that is called when a TransportStream receives
  a RST_STREAM frame.

## 0.1.1+2

* Add errorCode to exception toString message.

## 0.1.1+1

* Fixing a performance issue in case the underlying socket is not writeable
* Allow clients of MultiProtocolHttpServer to supply [http.ServerSettings]
* Allow the draft version 'h2-14' in the ALPN protocol negogiation.

## 0.1.1

* Adding support for MultiProtocolHttpServer in the
  `package:http2/multiprotocol_server.dart` library

## 0.1.0

* First version of a HTTP/2 transport implementation in the
  `package:http2/transport.dart` library

## 0.0.1

- Initial version
