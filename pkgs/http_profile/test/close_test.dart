// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:developer' show getHttpClientProfilingData;

import 'package:http_profile/http_profile.dart';
import 'package:test/test.dart';

void main() {
  late HttpClientRequestProfile profile;
  late Map<String, dynamic> backingMap;

  setUp(() {
    HttpClientRequestProfile.profilingEnabled = true;

    profile = HttpClientRequestProfile.profile(
      requestStartTime: DateTime.parse('2024-03-21'),
      requestMethod: 'GET',
      requestUri: 'https://www.example.com',
    )!;

    final profileBackingMaps = getHttpClientProfilingData();
    expect(profileBackingMaps.length, isPositive);
    backingMap = profileBackingMaps.lastOrNull!;
  });

  group('requestData.close', () {
    test('no arguments', () async {
      expect(backingMap['requestEndTimestamp'], isNull);
      await profile.requestData.close();

      expect(
        backingMap['requestEndTimestamp'],
        closeTo(DateTime.now().microsecondsSinceEpoch,
            Duration.microsecondsPerSecond),
      );
    });

    test('with time', () async {
      expect(backingMap['requestEndTimestamp'], isNull);
      await profile.requestData.close(DateTime.parse('2024-03-23'));

      expect(
        backingMap['requestEndTimestamp'],
        DateTime.parse('2024-03-23').microsecondsSinceEpoch,
      );
    });

    test('then write body', () async {
      await profile.requestData.close();

      expect(
        () => profile.requestData.bodySink.add([1, 2, 3]),
        throwsStateError,
      );
    });

    test('then mutate', () async {
      await profile.requestData.close();

      expect(
        () => profile.requestData.contentLength = 5,
        throwsStateError,
      );
    });
  });

  group('responseData.close', () {
    late Map<String, dynamic> responseData;

    setUp(() {
      responseData = backingMap['responseData'] as Map<String, dynamic>;
    });

    test('no arguments', () async {
      expect(responseData['endTime'], isNull);
      await profile.responseData.close();

      expect(
        responseData['endTime'],
        closeTo(DateTime.now().microsecondsSinceEpoch,
            Duration.microsecondsPerSecond),
      );
    });

    test('with time', () async {
      expect(responseData['endTime'], isNull);
      await profile.responseData.close(DateTime.parse('2024-03-23'));

      expect(
        responseData['endTime'],
        DateTime.parse('2024-03-23').microsecondsSinceEpoch,
      );
    });

    test('then write body', () async {
      await profile.responseData.close();

      expect(
        () => profile.responseData.bodySink.add([1, 2, 3]),
        throwsStateError,
      );
    });

    test('then mutate', () async {
      await profile.responseData.close();

      expect(
        () => profile.responseData.contentLength = 5,
        throwsStateError,
      );
    });
  });
}
