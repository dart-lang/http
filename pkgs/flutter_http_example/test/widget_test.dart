// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:flutter_http_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

const _singleBookResponse = '''
{
  "kind": "books#volumes",
  "totalItems": 2069,
  "items": [
    {
      "kind": "books#volume",
      "id": "gcnAEAAAQBAJ",
      "etag": "8yZ12V0pNUI",
      "selfLink": "https://www.googleapis.com/books/v1/volumes/gcnAEAAAQBAJ",
      "volumeInfo": {
        "title": "Flutter Cookbook",
        "subtitle": "100+ step-by-step recipes for building cross...",
        "authors": [
          "Simone Alessandria"
        ],
        "publisher": "Packt Publishing Ltd",
        "publishedDate": "2023-05-31",
        "description": "Write, test, and publish your web, desktop...",
    }]
}
''';

void main() {
  testWidgets('Test initial load', (WidgetTester tester) async {
    await tester.pumpWidget(const BookSearchApp());

    expect(find.text('Please enter a query'), findsOneWidget);
  });

  testWidgets('Test search', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path != '/books/v1/volumes') {
        return Response('', 404);
      }
      return Response(_singleBookResponse, 200);
    });

    // `runWithClient` doesn't work because `pumpWidget` does not
    // preserve the `Zone`.
    await runWithClient(
        () => tester.pumpWidget(const BookSearchApp()), () => mockClient);
    await tester.enterText(find.byType(TextField), 'Flutter Cookbook');
    await tester.pump();

    expect(find.text('Flutter Cookbook'), findsOneWidget);
    expect(find.text('Write, test, and publish your web, desktop...'),
        findsOneWidget);
  });
}
