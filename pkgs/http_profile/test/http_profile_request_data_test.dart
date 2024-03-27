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

    expect(profile.requestData.startTime, DateTime.parse('2024-03-21'));
    expect(profile.requestMethod, 'GET');
    expect(profile.requestUri, 'https://www.example.com');
  });

  test('populating HttpClientRequestProfile.requestEndTimestamp', () async {
    expect(backingMap['requestEndTimestamp'], isNull);
    expect(profile.requestData.endTime, isNull);

    await profile.requestData.close(DateTime.parse('2024-03-23'));

    expect(
      backingMap['requestEndTimestamp'],
      DateTime.parse('2024-03-23').microsecondsSinceEpoch,
    );
    expect(profile.requestData.endTime, DateTime.parse('2024-03-23'));
  });

  test('populating HttpClientRequestProfile.requestData.contentLength',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['contentLength'], isNull);
    expect(profile.requestData.contentLength, isNull);

    profile.requestData.contentLength = 1200;

    expect(requestData['contentLength'], 1200);
    expect(profile.requestData.contentLength, 1200);
  });

  test('HttpClientRequestProfile.requestData.contentLength = null', () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;

    profile.requestData.contentLength = 1200;
    expect(requestData['contentLength'], 1200);
    expect(profile.requestData.contentLength, 1200);

    profile.requestData.contentLength = null;
    expect(requestData['contentLength'], isNull);
    expect(profile.requestData.contentLength, isNull);
  });

  test('populating HttpClientRequestProfile.requestData.error', () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['error'], isNull);
    expect(profile.requestData.error, isNull);

    await profile.requestData.closeWithError('failed');

    expect(requestData['error'], 'failed');
    expect(profile.requestData.error, 'failed');
  });

  test('populating HttpClientRequestProfile.requestData.followRedirects',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['followRedirects'], isNull);
    expect(profile.requestData.followRedirects, isNull);

    profile.requestData.followRedirects = true;

    expect(requestData['followRedirects'], true);
    expect(profile.requestData.followRedirects, true);
  });

  test('HttpClientRequestProfile.requestData.followRedirects = null', () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;

    profile.requestData.followRedirects = true;
    expect(requestData['followRedirects'], true);
    expect(profile.requestData.followRedirects, true);

    profile.requestData.followRedirects = null;
    expect(requestData['followRedirects'], isNull);
    expect(profile.requestData.followRedirects, isNull);
  });

  test('populating HttpClientRequestProfile.requestData.headersListValues',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['headers'], isNull);
    expect(profile.requestData.headers, isNull);

    profile.requestData.headersListValues = {
      'fruit': ['apple', 'banana', 'grape'],
      'content-length': ['0'],
    };

    expect(
      requestData['headers'],
      {
        'fruit': ['apple', 'banana', 'grape'],
        'content-length': ['0'],
      },
    );
    expect(
      profile.requestData.headers,
      {
        'fruit': ['apple', 'banana', 'grape'],
        'content-length': ['0'],
      },
    );
  });

  test('HttpClientRequestProfile.requestData.headersListValues = null',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;

    profile.requestData.headersListValues = {
      'fruit': ['apple', 'banana', 'grape'],
      'content-length': ['0'],
    };
    expect(
      requestData['headers'],
      {
        'fruit': ['apple', 'banana', 'grape'],
        'content-length': ['0'],
      },
    );
    expect(
      profile.requestData.headers,
      {
        'fruit': ['apple', 'banana', 'grape'],
        'content-length': ['0'],
      },
    );

    profile.requestData.headersListValues = null;
    expect(requestData['headers'], isNull);
    expect(profile.requestData.headers, isNull);
  });

  test('populating HttpClientRequestProfile.requestData.headersCommaValues',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['headers'], isNull);
    expect(profile.requestData.headers, isNull);

    profile.requestData.headersCommaValues = {
      'set-cookie':
          // ignore: missing_whitespace_between_adjacent_strings
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO,'
              'sessionId=e8bb43229de9; Domain=foo.example.com'
    };

    expect(
      requestData['headers'],
      {
        'set-cookie': [
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO',
          'sessionId=e8bb43229de9; Domain=foo.example.com'
        ]
      },
    );
    expect(
      profile.requestData.headers,
      {
        'set-cookie': [
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO',
          'sessionId=e8bb43229de9; Domain=foo.example.com'
        ]
      },
    );
  });

  test('HttpClientRequestProfile.requestData.headersCommaValues = null',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;

    profile.requestData.headersCommaValues = {
      'set-cookie':
          // ignore: missing_whitespace_between_adjacent_strings
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO,'
              'sessionId=e8bb43229de9; Domain=foo.example.com'
    };
    expect(
      requestData['headers'],
      {
        'set-cookie': [
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO',
          'sessionId=e8bb43229de9; Domain=foo.example.com'
        ]
      },
    );
    expect(
      profile.requestData.headers,
      {
        'set-cookie': [
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO',
          'sessionId=e8bb43229de9; Domain=foo.example.com'
        ]
      },
    );

    profile.requestData.headersCommaValues = null;
    expect(requestData['headers'], isNull);
    expect(profile.requestData.headers, isNull);
  });

  test('populating HttpClientRequestProfile.requestData.maxRedirects',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['maxRedirects'], isNull);
    expect(profile.requestData.maxRedirects, isNull);

    profile.requestData.maxRedirects = 5;

    expect(requestData['maxRedirects'], 5);
    expect(profile.requestData.maxRedirects, 5);
  });

  test('HttpClientRequestProfile.requestData.maxRedirects = null', () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;

    profile.requestData.maxRedirects = 5;
    expect(requestData['maxRedirects'], 5);
    expect(profile.requestData.maxRedirects, 5);

    profile.requestData.maxRedirects = null;
    expect(requestData['maxRedirects'], isNull);
    expect(profile.requestData.maxRedirects, isNull);
  });

  test('populating HttpClientRequestProfile.requestData.persistentConnection',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['persistentConnection'], isNull);
    expect(profile.requestData.persistentConnection, isNull);

    profile.requestData.persistentConnection = true;

    expect(requestData['persistentConnection'], true);
    expect(profile.requestData.persistentConnection, true);
  });

  test('HttpClientRequestProfile.requestData.persistentConnection = null',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;

    profile.requestData.persistentConnection = true;
    expect(requestData['persistentConnection'], true);
    expect(profile.requestData.persistentConnection, true);

    profile.requestData.persistentConnection = null;
    expect(requestData['persistentConnection'], isNull);
    expect(profile.requestData.persistentConnection, isNull);
  });

  test('populating HttpClientRequestProfile.requestData.proxyDetails',
      () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;
    expect(requestData['proxyDetails'], isNull);
    expect(profile.requestData.proxyDetails, isNull);

    profile.requestData.proxyDetails = HttpProfileProxyData(
      host: 'https://www.example.com',
      username: 'abc123',
      isDirect: true,
      port: 4321,
    );

    final proxyDetailsFromBackingMap =
        requestData['proxyDetails'] as Map<String, dynamic>;
    expect(proxyDetailsFromBackingMap['host'], 'https://www.example.com');
    expect(proxyDetailsFromBackingMap['username'], 'abc123');
    expect(proxyDetailsFromBackingMap['isDirect'], true);
    expect(proxyDetailsFromBackingMap['port'], 4321);

    final proxyDetailsFromGetter = profile.requestData.proxyDetails!;
    expect(proxyDetailsFromGetter.host, 'https://www.example.com');
    expect(proxyDetailsFromGetter.username, 'abc123');
    expect(proxyDetailsFromGetter.isDirect, true);
    expect(proxyDetailsFromGetter.port, 4321);
  });

  test('HttpClientRequestProfile.requestData.proxyDetails = null', () async {
    final requestData = backingMap['requestData'] as Map<String, dynamic>;

    profile.requestData.proxyDetails = HttpProfileProxyData(
      host: 'https://www.example.com',
      username: 'abc123',
      isDirect: true,
      port: 4321,
    );

    final proxyDetailsFromBackingMap =
        requestData['proxyDetails'] as Map<String, dynamic>;
    expect(proxyDetailsFromBackingMap['host'], 'https://www.example.com');
    expect(proxyDetailsFromBackingMap['username'], 'abc123');
    expect(proxyDetailsFromBackingMap['isDirect'], true);
    expect(proxyDetailsFromBackingMap['port'], 4321);

    final proxyDetailsFromGetter = profile.requestData.proxyDetails!;
    expect(proxyDetailsFromGetter.host, 'https://www.example.com');
    expect(proxyDetailsFromGetter.username, 'abc123');
    expect(proxyDetailsFromGetter.isDirect, true);
    expect(proxyDetailsFromGetter.port, 4321);

    profile.requestData.proxyDetails = null;

    expect(requestData['proxyDetails'], isNull);
    expect(profile.requestData.proxyDetails, isNull);
  });

  test('using HttpClientRequestProfile.requestData.bodySink', () async {
    final requestBodyBytes = backingMap['requestBodyBytes'] as List<int>;
    expect(requestBodyBytes, isEmpty);
    expect(profile.requestData.bodyBytes, isEmpty);

    profile.requestData.bodySink.add([1, 2, 3]);
    profile.requestData.bodySink.addError('this is an error');
    profile.requestData.bodySink.add([4, 5]);
    await profile.requestData.close();

    expect(requestBodyBytes, [1, 2, 3, 4, 5]);
    expect(profile.requestData.bodyBytes, [1, 2, 3, 4, 5]);
  });
}
