import 'package:cupertinohttp/cupertinoclient.dart';
import 'package:cupertinohttp/cupertinohttp.dart';
import 'package:http_client_conformance_tests/http_client_conformance_tests.dart';
import 'package:test/test.dart';

void main() {
  group('defaultSessionConfiguration', () {
    testAll(CupertinoClient.defaultSessionConfiguration(),
        canStreamRequestBody: false);
  });
  group('fromSessionConfiguration', () {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration();
    testAll(CupertinoClient.fromSessionConfiguration(config),
        canStreamRequestBody: false);
  });
}
