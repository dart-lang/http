import 'package:cupertino_http/cupertino_http.dart';
import 'package:web_socket_conformance_tests/web_socket_conformance_tests.dart';

void main() {
  testAll((uri, {protocols}) => CupertinoWebSocket.connect(uri));
}
