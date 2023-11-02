// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_http_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const _singleBookResponse = '''
{
  "items": [
    {
      "volumeInfo": {
        "title": "Flutter Cookbook",
        "description": "Write, test, and publish your web, desktop...",
        "imageLinks": {
          "smallThumbnail": "http://books.google.com/books/content?id=gcnAEAAAQBAJ&printsec=frontcover&img=1&zoom=5&edge=curl&source=gbs_api"
        }
      }
    }
  ]
}
''';

void main() {
  Widget app(Client client) => Provider<Client>(
      create: (_) => client,
      child: const BookSearchApp(),
      dispose: (_, client) => client.close());

  testWidgets('test initial load', (WidgetTester tester) async {
    final mockClient = MockClient(
        (request) async => throw StateError('unexpected HTTP request'));

    await tester.pumpWidget(app(mockClient));

    expect(find.text('Please enter a query'), findsOneWidget);
  });

  testWidgets('test search with one result', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path != '/books/v1/volumes' &&
          request.url.queryParameters['q'] != 'Flutter') {
        return Response('', 404);
      }
      return Response(_singleBookResponse, 200);
    });

    await tester.pumpWidget(app(mockClient));
    await tester.enterText(find.byType(TextField), 'Flutter');
    await tester.pump();

    // The book title.
    expect(find.text('Flutter Cookbook'), findsOneWidget);
    // The book description.
    expect(
        find.text('Write, test, and publish your web, desktop...',
            skipOffstage: false),
        findsOneWidget);
  });
}
