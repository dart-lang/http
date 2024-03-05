import '../web_socket.dart';

Future<WebSocket> connect(Uri url, {Iterable<String>? protocols}) {
  throw UnsupportedError('Cannot connect without dart:js_interop or dart:io.');
}
