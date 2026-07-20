// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_http_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const _completionResponse = '''
{
  "packages": [
    "http",
    "http_parser",
    "shared_preferences"
  ]
}
''';

const _httpScoreResponse = '''
{
  "likeCount": 8458,
  "downloadCount30Days": 9436929
}
''';

const _httpParserScoreResponse = '''
{
  "likeCount": 150,
  "downloadCount30Days": 500000
}
''';

const _sharedPrefsScoreResponse = '''
{
  "likeCount": 3200,
  "downloadCount30Days": 4000000
}
''';

void main() {
  Widget app(Client client) => Provider<Client>(
      create: (_) => client,
      child: const PackageSearchApp(),
      dispose: (_, client) => client.close());

  testWidgets('test initial load displays all packages and loads scores',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/package-name-completion-data') {
        return Response(_completionResponse, 200);
      } else if (request.url.path == '/api/packages/http/score') {
        return Response(_httpScoreResponse, 200);
      } else if (request.url.path == '/api/packages/http_parser/score') {
        return Response(_httpParserScoreResponse, 200);
      } else if (request.url.path == '/api/packages/shared_preferences/score') {
        return Response(_sharedPrefsScoreResponse, 200);
      }
      throw StateError('unexpected HTTP request: ${request.url.path}');
    });

    await tester.pumpWidget(app(mockClient));
    // Wait for the completion data and all visible scores to load.
    await tester.pumpAndSettle();

    // Verify all package names are shown.
    expect(
      find.descendant(
        of: find.byType(PackageTable),
        matching: find.text('http'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(PackageTable),
        matching: find.text('http_parser'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(PackageTable),
        matching: find.text('shared_preferences'),
      ),
      findsOneWidget,
    );

    // Verify scores are loaded and displayed.
    expect(find.text('8458'), findsOneWidget);
    expect(find.text('9436929'), findsOneWidget);
    expect(find.text('3200'), findsOneWidget);
    expect(find.text('4000000'), findsOneWidget);
  });

  testWidgets('test search filters results', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/package-name-completion-data') {
        return Response(_completionResponse, 200);
      } else if (request.url.path == '/api/packages/http/score') {
        return Response(_httpScoreResponse, 200);
      } else if (request.url.path == '/api/packages/http_parser/score') {
        return Response(_httpParserScoreResponse, 200);
      } else if (request.url.path == '/api/packages/shared_preferences/score') {
        return Response(_sharedPrefsScoreResponse, 200);
      }
      return Response('', 404);
    });

    await tester.pumpWidget(app(mockClient));
    // Wait for initial load to finish.
    await tester.pumpAndSettle();

    // Search for 'http'
    await tester.enterText(find.byType(TextField), 'http');
    await tester.pumpAndSettle();

    // The matching package names should be present.
    expect(
      find.descendant(
        of: find.byType(PackageTable),
        matching: find.text('http'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(PackageTable),
        matching: find.text('http_parser'),
      ),
      findsOneWidget,
    );

    // The non-matching package should not be present.
    expect(
      find.descendant(
        of: find.byType(PackageTable),
        matching: find.text('shared_preferences'),
      ),
      findsNothing,
    );
  });
}
