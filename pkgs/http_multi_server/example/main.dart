import 'package:http_multi_server/http_multi_server.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() {
  // Both http://127.0.0.1:8080 and http://[::1]:8080 will be bound to the same
  // server.
  HttpMultiServer.loopback(8080).then((server) {
    shelf_io.serveRequests(server, (request) {
      return shelf.Response.ok("Hello, world!");
    });
  });
}
