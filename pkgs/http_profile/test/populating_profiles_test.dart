// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:developer' show getHttpClientProfilingData, Service;
import 'dart:io';
import 'dart:isolate' show Isolate;

import 'package:http_profile/http_profile.dart';
import 'package:test/test.dart';

void main() {
  late HttpClientRequestProfile profile;
  late Map<String, dynamic> backingMap;

  setUp(() {
    HttpClientRequestProfile.profilingEnabled = true;

    profile = HttpClientRequestProfile.profile(
      requestStartTimestamp: DateTime.parse('2024-03-21'),
      requestMethod: 'GET',
      requestUri: 'https://www.example.com',
    )!;

    final profileBackingMaps = getHttpClientProfilingData();
    expect(profileBackingMaps.length, isPositive);
    backingMap = profileBackingMaps.lastOrNull!;
  });

  test(
      'mandatory fields are populated when an HttpClientRequestProfile is '
      'constructed', () async {
    expect(backingMap['id'], isNotNull);
    expect(backingMap['isolateId'], Service.getIsolateId(Isolate.current)!);
    expect(
      backingMap['requestStartTimestamp'],
      DateTime.parse('2024-03-21').microsecondsSinceEpoch,
    );
    expect(backingMap['requestMethod'], 'GET');
    expect(backingMap['requestUri'], 'https://www.example.com');
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

  test('populating HttpClientRequestProfile.requestEndTimestamp', () async {
    expect(backingMap['requestEndTimestamp'], isNull);

    profile.requestEndTimestamp = DateTime.parse('2024-03-23');

    expect(
      backingMap['requestEndTimestamp'],
      DateTime.parse('2024-03-23').microsecondsSinceEpoch,
    );
  });

  test('populating HttpClientRequestProfile.requestData.connectionInfo',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['connectionInfo'], isNull);

    profile.requestData.connectionInfo = {
      'localPort': 1285,
      'remotePort': 443,
      'connectionPoolId': '21x23'
    };

    final connectionInfo =
        requestData['connectionInfo'] as Map<String, dynamic>;
    expect(connectionInfo['localPort'], 1285);
    expect(connectionInfo['remotePort'], 443);
    expect(connectionInfo['connectionPoolId'], '21x23');
  });

  test('populating HttpClientRequestProfile.requestData.contentLength',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['contentLength'], isNull);

    profile.requestData.contentLength = 1200;

    expect(requestData['contentLength'], 1200);
  });

  test('populating HttpClientRequestProfile.requestData.cookies', () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['cookies'], isNull);

    profile.requestData.cookies = <String>[
      'sessionId=abc123',
      'csrftoken=def456',
    ];

    final cookies = requestData['cookies'] as List<String>;
    expect(cookies.length, 2);
    expect(cookies[0], 'sessionId=abc123');
    expect(cookies[1], 'csrftoken=def456');
  });

  test('populating HttpClientRequestProfile.requestData.error', () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['error'], isNull);

    profile.requestData.error = 'failed';

    expect(requestData['error'], 'failed');
  });

  test('populating HttpClientRequestProfile.requestData.followRedirects',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['followRedirects'], isNull);

    profile.requestData.followRedirects = true;

    expect(requestData['followRedirects'], true);
  });

  test('populating HttpClientRequestProfile.requestData.headers', () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['headers'], isNull);

    profile.requestData.headers = {
      'content-length': ['0'],
    };

    final headers = requestData['headers'] as Map<String, List<String>>;
    expect(headers['content-length']!.length, 1);
    expect(headers['content-length']![0], '0');
  });

  test('populating HttpClientRequestProfile.requestData.maxRedirects',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['maxRedirects'], isNull);

    profile.requestData.maxRedirects = 5;

    expect(requestData['maxRedirects'], 5);
  });

  test('populating HttpClientRequestProfile.requestData.persistentConnection',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['persistentConnection'], isNull);

    profile.requestData.persistentConnection = true;

    expect(requestData['persistentConnection'], true);
  });

  test('populating HttpClientRequestProfile.requestData.proxyDetails',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['proxyDetails'], isNull);

    profile.requestData.proxyDetails = HttpProfileProxyData(
      host: 'https://www.example.com',
      username: 'abc123',
      isDirect: true,
      port: 4321,
    );

    final proxyDetails = requestData['proxyDetails'] as Map<String, dynamic>;
    expect(
      proxyDetails['host'],
      'https://www.example.com',
    );
    expect(proxyDetails['username'], 'abc123');
    expect(proxyDetails['isDirect'], true);
    expect(proxyDetails['port'], 4321);
  });

  test('calling HttpClientRequestProfile.responseData.addRedirect', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    final redirects = responseData['redirects'] as List<Map<String, dynamic>>;
    expect(redirects, isEmpty);

    profile.responseData.addRedirect(HttpProfileRedirectData(
      statusCode: 301,
      method: 'GET',
      location: 'https://images.example.com/1',
    ));

    expect(redirects.length, 1);
    final redirect = redirects.last;
    expect(redirect['statusCode'], 301);
    expect(redirect['method'], 'GET');
    expect(redirect['location'], 'https://images.example.com/1');
  });

  test('populating HttpClientRequestProfile.responseData.cookies', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['cookies'], isNull);

    profile.responseData.cookies = <String>[
      'sessionId=abc123',
      'id=def456; Max-Age=2592000; Domain=example.com',
    ];

    final cookies = responseData['cookies'] as List<String>;
    expect(cookies.length, 2);
    expect(cookies[0], 'sessionId=abc123');
    expect(cookies[1], 'id=def456; Max-Age=2592000; Domain=example.com');
  });

  test('populating HttpClientRequestProfile.responseData.connectionInfo',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['connectionInfo'], isNull);

    profile.responseData.connectionInfo = {
      'localPort': 1285,
      'remotePort': 443,
      'connectionPoolId': '21x23'
    };

    final connectionInfo =
        responseData['connectionInfo'] as Map<String, dynamic>;
    expect(connectionInfo['localPort'], 1285);
    expect(connectionInfo['remotePort'], 443);
    expect(connectionInfo['connectionPoolId'], '21x23');
  });

  test('populating HttpClientRequestProfile.responseData.headers', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['headers'], isNull);

    profile.responseData.headers = {
      'connection': ['keep-alive'],
      'cache-control': ['max-age=43200'],
      'content-type': ['application/json', 'charset=utf-8'],
    };

    final headers = responseData['headers'] as Map<String, List<String>>;
    expect(headers['connection']!.length, 1);
    expect(headers['connection']![0], 'keep-alive');
    expect(headers['cache-control']!.length, 1);
    expect(headers['cache-control']![0], 'max-age=43200');
    expect(headers['content-type']!.length, 2);
    expect(headers['content-type']![0], 'application/json');
    expect(headers['content-type']![1], 'charset=utf-8');
  });

  test('populating HttpClientRequestProfile.responseData.compressionState',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['compressionState'], isNull);

    profile.responseData.compressionState =
        HttpClientResponseCompressionState.decompressed;

    expect(responseData['compressionState'], 'decompressed');
  });

  test('populating HttpClientRequestProfile.responseData.reasonPhrase',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['reasonPhrase'], isNull);

    profile.responseData.reasonPhrase = 'OK';

    expect(responseData['reasonPhrase'], 'OK');
  });

  test('populating HttpClientRequestProfile.responseData.isRedirect', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['isRedirect'], isNull);

    profile.responseData.isRedirect = true;

    expect(responseData['isRedirect'], true);
  });

  test('populating HttpClientRequestProfile.responseData.persistentConnection',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['persistentConnection'], isNull);

    profile.responseData.persistentConnection = true;

    expect(responseData['persistentConnection'], true);
  });

  test('populating HttpClientRequestProfile.responseData.contentLength',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['contentLength'], isNull);

    profile.responseData.contentLength = 1200;

    expect(responseData['contentLength'], 1200);
  });

  test('populating HttpClientRequestProfile.responseData.statusCode', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['statusCode'], isNull);

    profile.responseData.statusCode = 200;

    expect(responseData['statusCode'], 200);
  });

  test('populating HttpClientRequestProfile.responseData.startTime', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['startTime'], isNull);

    profile.responseData.startTime = DateTime.parse('2024-03-21');

    expect(
      responseData['startTime'],
      DateTime.parse('2024-03-21').microsecondsSinceEpoch,
    );
  });

  test('populating HttpClientRequestProfile.responseData.endTime', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['endTime'], isNull);

    profile.responseData.endTime = DateTime.parse('2024-03-23');

    expect(
      responseData['endTime'],
      DateTime.parse('2024-03-23').microsecondsSinceEpoch,
    );
  });

  test('populating HttpClientRequestProfile.responseData.error', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['error'], isNull);

    profile.responseData.error = 'failed';

    expect(responseData['error'], 'failed');
  });

  test('using HttpClientRequestProfile.requestBodySink', () async {
    final requestBodyStream =
        backingMap['_requestBodyStream'] as Stream<List<int>>;

    profile.requestBodySink.add([1, 2, 3]);

    await Future.wait([
      Future.sync(
        () async => expect(
          await requestBodyStream.expand((i) => i).toList(),
          [1, 2, 3],
        ),
      ),
      profile.requestBodySink.close(),
    ]);
  });

  test('using HttpClientRequestProfile.responseBodySink', () async {
    final requestBodyStream =
        backingMap['_responseBodyStream'] as Stream<List<int>>;

    profile.responseBodySink.add([1, 2, 3]);

    await Future.wait([
      Future.sync(
        () async => expect(
          await requestBodyStream.expand((i) => i).toList(),
          [1, 2, 3],
        ),
      ),
      profile.responseBodySink.close(),
    ]);
  });
}
