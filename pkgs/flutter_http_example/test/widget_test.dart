// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

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
          "smallThumbnail": "http://thumbnailurl/"
        }
      }
    }
  ]
}
''';

final _dummyPngImage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmM'
  'IQAAAABJRU5ErkJggg==',
);

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
      if (request.url.path == '/books/v1/volumes' &&
          request.url.queryParameters['q'] == 'Flutter') {
        return Response(_singleBookResponse, 200);
      } else if (request.url == Uri.https('thumbnailurl', '/')) {
        return Response.bytes(_dummyPngImage, 200,
            headers: const {'Content-Type': 'image/png'});
      }
      return Response('', 404);
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
