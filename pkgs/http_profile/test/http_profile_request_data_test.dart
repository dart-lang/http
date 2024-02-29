// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:developer' show Service, getHttpClientProfilingData;
import 'dart:isolate' show Isolate;

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

  test('populating HttpClientRequestProfile.requestEndTimestamp', () async {
    expect(backingMap['requestEndTimestamp'], isNull);
    profile.requestData.close(DateTime.parse('2024-03-23'));

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

  test('HttpClientRequestProfile.requestData.contentLength = nil', () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;

    profile.requestData.contentLength = 1200;
    expect(requestData['contentLength'], 1200);

    profile.requestData.contentLength = null;
    expect(requestData['contentLength'], isNull);
  });

  test('populating HttpClientRequestProfile.requestData.error', () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['error'], isNull);

    profile.requestData.closeWithError('failed');

    expect(requestData['error'], 'failed');
  });

  test('populating HttpClientRequestProfile.requestData.followRedirects',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['followRedirects'], isNull);

    profile.requestData.followRedirects = true;

    expect(requestData['followRedirects'], true);
  });

  test('populating HttpClientRequestProfile.requestData.headersListValues',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['headers'], isNull);

    profile.requestData.headersListValues = {
      'fruit': ['apple', 'banana', 'grape'],
      'content-length': ['0'],
    };

    final headers = requestData['headers'] as Map<String, List<String>>;
    expect(headers, {
      'fruit': ['apple', 'banana', 'grape'],
      'content-length': ['0'],
    });
  });

  test('populating HttpClientRequestProfile.requestData.headersCommaValues',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['headers'], isNull);

    profile.requestData.headersCommaValues = {
      'set-cookie':
          // ignore: missing_whitespace_between_adjacent_strings
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO,'
              'sessionId=e8bb43229de9; Domain=foo.example.com'
    };

    final headers = requestData['headers'] as Map<String, List<String>>;
    expect(headers, {
      'set-cookie': [
        'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO',
        'sessionId=e8bb43229de9; Domain=foo.example.com'
      ]
    });
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
}
