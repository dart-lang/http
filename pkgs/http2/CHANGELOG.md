## 3.0.1-wip

- Gracefully handle receiving headers on a stream that the client has canceled. (#1799)

## 3.0.0

- Require Dart SDK `3.7.0`.
- Add support for providing custom message when terminating a connection.

## 2.3.1

- Require Dart 3.2
- Add topics to `pubspec.yaml`
- Move to `dart-lang/http` monorepo.

## 2.3.0

- Only send updates on frames and pings being received when there are listeners, as to not fill up memory.

## 2.2.0

- Transform headers to lowercase.
- Expose pings to connection to enable the KEEPALIVE feature for gRPC.

## 2.1.0

- Require Dart `3.0.0`
- Require Dart `2.17.0`.
- Send `WINDOW_UPDATE` frames for the connection to account for data being sent on closed streams until the `RST_STREAM` has been processed.

## 2.0.1

- Simplify the implementation of `MultiProtocolHttpServer.close`.
- Require Dart `2.15.0`.

## 2.0.0

* Migrate to null safety.

## 1.0.1

* Add `TransportConnection.onInitialPeerSettingsReceived` which fires when
  initial SETTINGS frame is received from the peer.

## 1.0.0

* Graduate package to 1.0.
* `package:http2/http2.dart` now reexports `package:http2/transport.dart`.

## 0.1.9

* Discard messages incoming after stream cancellation.

## 0.1.8+2

* On connection termination, try to dispatch existing messages, thereby avoiding
  terminating existing streams.

* Fix `ClientTransportConnection.isOpen` to return `false` if we have exhausted
  the number of max-concurrent-streams.

## 0.1.8+1

* Switch all uppercase constants from `dart:convert` to lowercase.

## 0.1.8

* More changes required for making tests pass under Dart 2.0 runtime.
* Modify sdk constraint to require '>=2.0.0-dev.40.0'.

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
