import 'package:websocket/iowebsocket.dart';
import 'package:websocket/websocket.dart';
import 'package:web_socket_conformance_tests/web_socket_conformance_tests.dart';

import 'package:test/test.dart';

void main() {
  testAll((uri, {protocols}) => IOWebSocket.connect(uri));
}
