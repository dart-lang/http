import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // TODO: Re-enable when http_client_conformance_tests supports Flutter
  // plugins
  //
  // group('defaultSessionConfiguration', () {
  //   testAll(CupertinoClient.defaultSessionConfiguration(),
  //       canStreamRequestBody: false);
  // });
  // group('fromSessionConfiguration', () {
  //   final config = URLSessionConfiguration.ephemeralSessionConfiguration();
  //   testAll(CupertinoClient.fromSessionConfiguration(config),
  //       canStreamRequestBody: false);
  // });
}
