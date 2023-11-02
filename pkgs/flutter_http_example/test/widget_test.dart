// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter_http_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Test initial load', (WidgetTester tester) async {
    await tester.pumpWidget(const BookSearchApp());

    expect(find.text('Please enter a query'), findsOneWidget);
  });
}
