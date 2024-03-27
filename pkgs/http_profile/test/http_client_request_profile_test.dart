// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:developer';
import 'dart:io';

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
    final eventsFromBackingMap =
        backingMap['events'] as List<Map<String, dynamic>>;
    expect(eventsFromBackingMap, isEmpty);

    expect(profile.events, isEmpty);

    profile.addEvent(HttpProfileRequestEvent(
      timestamp: DateTime.parse('2024-03-22'),
      name: 'an event',
    ));

    expect(eventsFromBackingMap.length, 1);
    final eventFromBackingMap = eventsFromBackingMap.last;
    expect(
      eventFromBackingMap['timestamp'],
      DateTime.parse('2024-03-22').microsecondsSinceEpoch,
    );
    expect(eventFromBackingMap['event'], 'an event');

    expect(profile.events.length, 1);
    final eventFromGetter = profile.events.first;
    expect(eventFromGetter.timestamp, DateTime.parse('2024-03-22'));
    expect(eventFromGetter.name, 'an event');
  });

  test('populating HttpClientRequestProfile.connectionInfo', () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(requestData['connectionInfo'], isNull);
    expect(responseData['connectionInfo'], isNull);
    expect(profile.connectionInfo, isNull);

    profile.connectionInfo = {
      'localPort': 1285,
      'remotePort': 443,
      'connectionPoolId': '21x23'
    };

    final connectionInfoFromRequestData =
        requestData['connectionInfo'] as Map<String, dynamic>;
    final connectionInfoFromResponseData =
        responseData['connectionInfo'] as Map<String, dynamic>;
    expect(connectionInfoFromRequestData['localPort'], 1285);
    expect(connectionInfoFromResponseData['localPort'], 1285);
    expect(connectionInfoFromRequestData['remotePort'], 443);
    expect(connectionInfoFromResponseData['remotePort'], 443);
    expect(connectionInfoFromRequestData['connectionPoolId'], '21x23');
    expect(connectionInfoFromResponseData['connectionPoolId'], '21x23');

    final connectionInfoFromGetter = profile.connectionInfo!;
    expect(connectionInfoFromGetter['localPort'], 1285);
    expect(connectionInfoFromGetter['remotePort'], 443);
    expect(connectionInfoFromGetter['connectionPoolId'], '21x23');
  });

  test('HttpClientRequestProfile.connectionInfo = null', () async {
    profile.connectionInfo = {
      'localPort': 1285,
      'remotePort': 443,
      'connectionPoolId': '21x23'
    };

    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    final connectionInfoFromRequestData =
        requestData['connectionInfo'] as Map<String, dynamic>;
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    final connectionInfoFromResponseData =
        responseData['connectionInfo'] as Map<String, dynamic>;
    expect(connectionInfoFromRequestData['localPort'], 1285);
    expect(connectionInfoFromResponseData['localPort'], 1285);
    expect(connectionInfoFromRequestData['remotePort'], 443);
    expect(connectionInfoFromResponseData['remotePort'], 443);
    expect(connectionInfoFromRequestData['connectionPoolId'], '21x23');
    expect(connectionInfoFromResponseData['connectionPoolId'], '21x23');

    final connectionInfoFromGetter = profile.connectionInfo!;
    expect(connectionInfoFromGetter['localPort'], 1285);
    expect(connectionInfoFromGetter['remotePort'], 443);
    expect(connectionInfoFromGetter['connectionPoolId'], '21x23');

    profile.connectionInfo = null;

    expect(requestData['connectionInfo'], isNull);
    expect(responseData['connectionInfo'], isNull);
    expect(profile.connectionInfo, isNull);
  });
}
