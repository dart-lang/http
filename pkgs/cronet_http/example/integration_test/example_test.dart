@Skip('example test that is brittle because if requires network access')

import 'package:cronet_http_example/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('search test', () {
    testWidgets('search for a book', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final search = find.byType(TextField);
      await tester.enterText(search, 'Dart Apprentice (First Edition)');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
          // From the synopsis for 'Dart Apprentice (First Edition).
          find.textContaining('Make Dart Your Programming Language of Choice'),
          findsOneWidget);
    });
  });
}
