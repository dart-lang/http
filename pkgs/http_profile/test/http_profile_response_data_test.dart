// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:developer' show getHttpClientProfilingData;
import 'dart:io';

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

  test('populating HttpClientRequestProfile.responseData.headersListValues',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['headers'], isNull);

    profile.responseData.headersListValues = {
      'connection': ['keep-alive'],
      'cache-control': ['max-age=43200'],
      'content-type': ['application/json', 'charset=utf-8'],
    };

    final headers = responseData['headers'] as Map<String, List<String>>;
    expect(headers, {
      'connection': ['keep-alive'],
      'cache-control': ['max-age=43200'],
      'content-type': ['application/json', 'charset=utf-8'],
    });
  });

  test('populating HttpClientRequestProfile.responseData.headersCommaValues',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['headers'], isNull);

    profile.responseData.headersCommaValues = {
      'set-cookie':
          // ignore: missing_whitespace_between_adjacent_strings
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO,'
              'sessionId=e8bb43229de9; Domain=foo.example.com'
    };

    final headers = responseData['headers'] as Map<String, List<String>>;
    expect(headers, {
      'set-cookie': [
        'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO',
        'sessionId=e8bb43229de9; Domain=foo.example.com'
      ]
    });
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

  test('HttpClientRequestProfile.responseData.contentLength = nil', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    profile.responseData.contentLength = 1200;
    expect(responseData['contentLength'], 1200);

    profile.responseData.contentLength = null;
    expect(responseData['contentLength'], isNull);
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

    await profile.responseData.close(DateTime.parse('2024-03-23'));

    expect(
      responseData['endTime'],
      DateTime.parse('2024-03-23').microsecondsSinceEpoch,
    );
  });

  test('populating HttpClientRequestProfile.responseData.error', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['error'], isNull);

    await profile.responseData.closeWithError('failed');

    expect(responseData['error'], 'failed');
  });

  test('using HttpClientRequestProfile.responseData.bodySink', () async {
    final responseBodyBytes = backingMap['responseBodyBytes'] as List<int>;
    expect(responseBodyBytes, isEmpty);
    expect(profile.responseData.bodyBytes, isEmpty);

    profile.responseData.bodySink.add([1, 2, 3]);
    await profile.responseData.close();

    expect(responseBodyBytes, [1, 2, 3]);
    expect(profile.responseData.bodyBytes, [1, 2, 3]);
  });
}
