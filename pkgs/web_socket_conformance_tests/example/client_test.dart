import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';
import 'package:web_socket_conformance_tests/web_socket_conformance_tests.dart';

class MyWebSocketImplementation implements WebSocket {
  // Implement the `WebSocket` interface.

  static Future<MyWebSocketImplementation> connect(Uri uri) {
    return MyWebSocketImplementation();
  }
}

void main() {
  group('client conformance tests', () {
    testAll(MyWebSocketImplementation.connect);
  });
}
