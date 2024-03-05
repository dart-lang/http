import 'package:test/test.dart';
import 'package:web_socket/web_socket.dart';

/// Tests that the [WebSocket] rejects invalid connection URIs.
void testConnectUri(
    Future<WebSocket> Function(Uri uri, {Iterable<String>? protocols})
        channelFactory) {
  group('connect uri', () {
    test('no protocol', () async {
      await expectLater(() => channelFactory(Uri.https('www.example.com', '/')),
          throwsA(isA<WebSocketException>()));
    });
  });
}
