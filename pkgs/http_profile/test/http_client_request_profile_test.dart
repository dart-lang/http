// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:developer';

import 'package:http_profile/src/http_profile.dart';
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

  test('profiling enabled', () async {
    HttpClientRequestProfile.profilingEnabled = true;
    expect(HttpClient.enableTimelineLogging, true);
    expect(
      HttpClientRequestProfile.profile(
        requestStartTime: DateTime.parse('2024-03-21'),
        requestMethod: 'GET',
        requestUri: 'https://www.example.com',
      ),
      isNotNull,
    );
  });

  test('profiling disabled', () async {
    HttpClientRequestProfile.profilingEnabled = false;
    expect(HttpClient.enableTimelineLogging, false);
    expect(
      HttpClientRequestProfile.profile(
        requestStartTime: DateTime.parse('2024-03-21'),
        requestMethod: 'GET',
        requestUri: 'https://www.example.com',
      ),
      isNull,
    );
  });

  test('calling HttpClientRequestProfile.addEvent', () async {
    final events = backingMap['events'] as List<Map<String, dynamic>>;
    expect(events, isEmpty);

    profile.addEvent(HttpProfileRequestEvent(
      timestamp: DateTime.parse('2024-03-22'),
      name: 'an event',
    ));

    expect(events.length, 1);
    final event = events.last;
    expect(
      event['timestamp'],
      DateTime.parse('2024-03-22').microsecondsSinceEpoch,
    );
    expect(event['event'], 'an event');
  });
}
