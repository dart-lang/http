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

const _transparentPng = [
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  11,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  96,
  0,
  0,
  0,
  2,
  0,
  1,
  226,
  33,
  188,
  51,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130
];

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
      } else if (request.url.path == '/api/packages/http/publisher') {
        return Response('{"publisherId": "dart.dev"}', 200);
      } else if (request.url.path == '/api/packages/http_parser/score') {
        return Response(_httpParserScoreResponse, 200);
      } else if (request.url.path == '/api/packages/http_parser/publisher') {
        return Response('{"publisherId": "dart.dev"}', 200);
      } else if (request.url.path == '/api/packages/shared_preferences/score') {
        return Response(_sharedPrefsScoreResponse, 200);
      } else if (request.url.path ==
          '/api/packages/shared_preferences/publisher') {
        return Response('{"publisherId": "flutter.dev"}', 200);
      } else if (request.url.path == '/s2/favicons') {
        return Response.bytes(_transparentPng, 200);
      }
      throw StateError('unexpected HTTP request: ${request.url.path}');
    });

    await tester.pumpWidget(app(mockClient));
    // Wait for the completion data and all visible scores to load.
    await tester.pumpAndSettle();

    // Verify all package names are shown.
    expect(
      find.descendant(
        of: find.byType(PackageList),
        matching: find.text('http'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(PackageList),
        matching: find.text('http_parser'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(PackageList),
        matching: find.text('shared_preferences'),
      ),
      findsOneWidget,
    );

    // Verify publisher domains are shown.
    expect(find.text('dart.dev'), findsNWidgets(2));
    expect(find.text('flutter.dev'), findsOneWidget);

    // Verify scores are loaded and displayed.
    expect(find.text('8458 Likes'), findsOneWidget);
    expect(find.text('9436929 Downloads'), findsOneWidget);
  });

  testWidgets('test search filters results', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/package-name-completion-data') {
        return Response(_completionResponse, 200);
      } else if (request.url.path == '/api/packages/http/score') {
        return Response(_httpScoreResponse, 200);
      } else if (request.url.path == '/api/packages/http/publisher') {
        return Response('{"publisherId": "dart.dev"}', 200);
      } else if (request.url.path == '/api/packages/http_parser/score') {
        return Response(_httpParserScoreResponse, 200);
      } else if (request.url.path == '/api/packages/http_parser/publisher') {
        return Response('{"publisherId": "dart.dev"}', 200);
      } else if (request.url.path == '/api/packages/shared_preferences/score') {
        return Response(_sharedPrefsScoreResponse, 200);
      } else if (request.url.path ==
          '/api/packages/shared_preferences/publisher') {
        return Response('{"publisherId": "flutter.dev"}', 200);
      } else if (request.url.path == '/s2/favicons') {
        return Response.bytes(_transparentPng, 200);
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
        of: find.byType(PackageList),
        matching: find.text('http'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(PackageList),
        matching: find.text('http_parser'),
      ),
      findsOneWidget,
    );

    // The non-matching package should not be present.
    expect(
      find.descendant(
        of: find.byType(PackageList),
        matching: find.text('shared_preferences'),
      ),
      findsNothing,
    );
  });

  testWidgets('test load package list error displays error and retry',
      (WidgetTester tester) async {
    var requestCount = 0;
    final mockClient = MockClient((request) async {
      requestCount++;
      if (requestCount == 1) {
        return Response('Internal Server Error', 500);
      }
      if (request.url.path == '/api/package-name-completion-data') {
        return Response(_completionResponse, 200);
      } else if (request.url.path == '/api/packages/http/score') {
        return Response(_httpScoreResponse, 200);
      } else if (request.url.path == '/api/packages/http/publisher') {
        return Response('{"publisherId": "dart.dev"}', 200);
      } else if (request.url.path == '/api/packages/http_parser/score') {
        return Response(_httpParserScoreResponse, 200);
      } else if (request.url.path == '/api/packages/http_parser/publisher') {
        return Response('{"publisherId": "dart.dev"}', 200);
      } else if (request.url.path == '/api/packages/shared_preferences/score') {
        return Response(_sharedPrefsScoreResponse, 200);
      } else if (request.url.path ==
          '/api/packages/shared_preferences/publisher') {
        return Response('{"publisherId": "flutter.dev"}', 200);
      } else if (request.url.path == '/s2/favicons') {
        return Response.bytes(_transparentPng, 200);
      }
      return Response('', 404);
    });

    await tester.pumpWidget(app(mockClient));
    await tester.pumpAndSettle();

    // Verify error message and retry button are shown.
    expect(
        find.text('Failed to load package list: Status 500'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);

    // Tap retry.
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // Verify package list loads successfully after retry.
    expect(
      find.descendant(
        of: find.byType(PackageList),
        matching: find.text('http'),
      ),
      findsOneWidget,
    );
  });
}
