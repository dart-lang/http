# Changelog

## Unreleased

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
