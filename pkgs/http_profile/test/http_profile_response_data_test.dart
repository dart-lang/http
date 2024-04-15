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

  group('HttpProfileRedirectData', () {
    test('equal', () {
      expect(
          HttpProfileRedirectData(
              statusCode: 302, method: 'GET', location: 'http://somewhere'),
          HttpProfileRedirectData(
              statusCode: 302, method: 'GET', location: 'http://somewhere'));
    });

    test('not equal', () {
      expect(
          HttpProfileRedirectData(
              statusCode: 302, method: 'GET', location: 'http://somewhere'),
          isNot(Object()));
      expect(
          HttpProfileRedirectData(
              statusCode: 302, method: 'GET', location: 'http://somewhere'),
          isNot(HttpProfileRedirectData(
              statusCode: 303, method: 'GET', location: 'http://somewhere')));
      expect(
          HttpProfileRedirectData(
              statusCode: 302, method: 'GET', location: 'http://somewhere'),
          isNot(HttpProfileRedirectData(
              statusCode: 302, method: 'POST', location: 'http://somewhere')));
      expect(
          HttpProfileRedirectData(
              statusCode: 302, method: 'GET', location: 'http://somewhere'),
          isNot(HttpProfileRedirectData(
              statusCode: 302, method: 'GET', location: 'http://notthere')));
    });

    test('hash', () {
      expect(
          HttpProfileRedirectData(
                  statusCode: 302, method: 'GET', location: 'http://somewhere')
              .hashCode,
          HttpProfileRedirectData(
                  statusCode: 302, method: 'GET', location: 'http://somewhere')
              .hashCode);
    });
  });

  test('calling HttpClientRequestProfile.responseData.addRedirect', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    final redirectsFromBackingMap =
        responseData['redirects'] as List<Map<String, dynamic>>;
    expect(redirectsFromBackingMap, isEmpty);
    expect(profile.responseData.redirects, isEmpty);

    profile.responseData.addRedirect(HttpProfileRedirectData(
      statusCode: 301,
      method: 'GET',
      location: 'https://images.example.com/1',
    ));

    expect(redirectsFromBackingMap.length, 1);
    final redirectFromBackingMap = redirectsFromBackingMap.last;
    expect(redirectFromBackingMap['statusCode'], 301);
    expect(redirectFromBackingMap['method'], 'GET');
    expect(redirectFromBackingMap['location'], 'https://images.example.com/1');

    expect(profile.responseData.redirects, [
      HttpProfileRedirectData(
        statusCode: 301,
        method: 'GET',
        location: 'https://images.example.com/1',
      )
    ]);
  });

  test('populating HttpClientRequestProfile.responseData.headersListValues',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['headers'], isNull);
    expect(profile.responseData.headers, isNull);

    profile.responseData.headersListValues = {
      'connection': ['keep-alive'],
      'cache-control': ['max-age=43200'],
      'content-type': ['application/json', 'charset=utf-8'],
    };

    expect(
      responseData['headers'],
      {
        'connection': ['keep-alive'],
        'cache-control': ['max-age=43200'],
        'content-type': ['application/json', 'charset=utf-8'],
      },
    );
    expect(
      profile.responseData.headers,
      {
        'connection': ['keep-alive'],
        'cache-control': ['max-age=43200'],
        'content-type': ['application/json', 'charset=utf-8'],
      },
    );
  });

  test('HttpClientRequestProfile.responseData.headersListValues = null',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;

    profile.responseData.headersListValues = {
      'connection': ['keep-alive'],
      'cache-control': ['max-age=43200'],
      'content-type': ['application/json', 'charset=utf-8'],
    };
    expect(
      responseData['headers'],
      {
        'connection': ['keep-alive'],
        'cache-control': ['max-age=43200'],
        'content-type': ['application/json', 'charset=utf-8'],
      },
    );
    expect(
      profile.responseData.headers,
      {
        'connection': ['keep-alive'],
        'cache-control': ['max-age=43200'],
        'content-type': ['application/json', 'charset=utf-8'],
      },
    );

    profile.responseData.headersListValues = null;
    expect(responseData['headers'], isNull);
    expect(profile.responseData.headers, isNull);
  });

  test('populating HttpClientRequestProfile.responseData.headersCommaValues',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['headers'], isNull);
    expect(profile.responseData.headers, isNull);

    profile.responseData.headersCommaValues = {
      'set-cookie':
          // ignore: missing_whitespace_between_adjacent_strings
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO,'
              'sessionId=e8bb43229de9; Domain=foo.example.com'
    };

    expect(
      responseData['headers'],
      {
        'set-cookie': [
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO',
          'sessionId=e8bb43229de9; Domain=foo.example.com'
        ]
      },
    );
    expect(
      profile.responseData.headers,
      {
        'set-cookie': [
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO',
          'sessionId=e8bb43229de9; Domain=foo.example.com'
        ]
      },
    );
  });

  test('HttpClientRequestProfile.responseData.headersCommaValues = null',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;

    profile.responseData.headersCommaValues = {
      'set-cookie':
          // ignore: missing_whitespace_between_adjacent_strings
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO,'
              'sessionId=e8bb43229de9; Domain=foo.example.com'
    };
    expect(
      responseData['headers'],
      {
        'set-cookie': [
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO',
          'sessionId=e8bb43229de9; Domain=foo.example.com'
        ]
      },
    );
    expect(
      profile.responseData.headers,
      {
        'set-cookie': [
          'id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/,,HE,=L=LO',
          'sessionId=e8bb43229de9; Domain=foo.example.com'
        ]
      },
    );

    profile.responseData.headersCommaValues = null;
    expect(responseData['headers'], isNull);
    expect(profile.responseData.headers, isNull);
  });

  test('populating HttpClientRequestProfile.responseData.compressionState',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['compressionState'], isNull);
    expect(profile.responseData.compressionState, isNull);

    profile.responseData.compressionState =
        HttpClientResponseCompressionState.decompressed;

    expect(responseData['compressionState'], 'decompressed');
    expect(
      profile.responseData.compressionState,
      HttpClientResponseCompressionState.decompressed,
    );
  });

  test('HttpClientRequestProfile.responseData.compressionState = null',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;

    profile.responseData.compressionState =
        HttpClientResponseCompressionState.decompressed;
    expect(responseData['compressionState'], 'decompressed');
    expect(
      profile.responseData.compressionState,
      HttpClientResponseCompressionState.decompressed,
    );

    profile.responseData.compressionState = null;
    expect(responseData['compressionState'], isNull);
    expect(profile.responseData.compressionState, isNull);
  });

  test('populating HttpClientRequestProfile.responseData.reasonPhrase',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['reasonPhrase'], isNull);
    expect(profile.responseData.reasonPhrase, isNull);

    profile.responseData.reasonPhrase = 'OK';

    expect(responseData['reasonPhrase'], 'OK');
    expect(profile.responseData.reasonPhrase, 'OK');
  });

  test('HttpClientRequestProfile.responseData.reasonPhrase = null', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;

    profile.responseData.reasonPhrase = 'OK';
    expect(responseData['reasonPhrase'], 'OK');
    expect(profile.responseData.reasonPhrase, 'OK');

    profile.responseData.reasonPhrase = null;
    expect(responseData['reasonPhrase'], isNull);
    expect(profile.responseData.reasonPhrase, isNull);
  });

  test('populating HttpClientRequestProfile.responseData.isRedirect', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['isRedirect'], isNull);
    expect(profile.responseData.isRedirect, isNull);

    profile.responseData.isRedirect = true;

    expect(responseData['isRedirect'], true);
    expect(profile.responseData.isRedirect, true);
  });

  test('HttpClientRequestProfile.responseData.isRedirect = null', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;

    profile.responseData.isRedirect = true;
    expect(responseData['isRedirect'], true);
    expect(profile.responseData.isRedirect, true);

    profile.responseData.isRedirect = null;
    expect(responseData['isRedirect'], isNull);
    expect(profile.responseData.isRedirect, isNull);
  });

  test('populating HttpClientRequestProfile.responseData.persistentConnection',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['persistentConnection'], isNull);
    expect(profile.responseData.persistentConnection, isNull);

    profile.responseData.persistentConnection = true;

    expect(responseData['persistentConnection'], true);
    expect(profile.responseData.persistentConnection, true);
  });

  test('HttpClientRequestProfile.responseData.persistentConnection = null',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;

    profile.responseData.persistentConnection = true;
    expect(responseData['persistentConnection'], true);
    expect(profile.responseData.persistentConnection, true);

    profile.responseData.persistentConnection = null;
    expect(responseData['persistentConnection'], isNull);
    expect(profile.responseData.persistentConnection, isNull);
  });

  test('populating HttpClientRequestProfile.responseData.contentLength',
      () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['contentLength'], isNull);
    expect(profile.responseData.contentLength, isNull);

    profile.responseData.contentLength = 1200;

    expect(responseData['contentLength'], 1200);
    expect(profile.responseData.contentLength, 1200);
  });

  test('HttpClientRequestProfile.responseData.contentLength = null', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;

    profile.responseData.contentLength = 1200;
    expect(responseData['contentLength'], 1200);
    expect(profile.responseData.contentLength, 1200);

    profile.responseData.contentLength = null;
    expect(responseData['contentLength'], isNull);
    expect(profile.responseData.contentLength, isNull);
  });

  test('populating HttpClientRequestProfile.responseData.statusCode', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['statusCode'], isNull);
    expect(profile.responseData.statusCode, isNull);

    profile.responseData.statusCode = 200;

    expect(responseData['statusCode'], 200);
    expect(profile.responseData.statusCode, 200);
  });

  test('HttpClientRequestProfile.responseData.statusCode = null', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;

    profile.responseData.statusCode = 200;
    expect(responseData['statusCode'], 200);
    expect(profile.responseData.statusCode, 200);

    profile.responseData.statusCode = null;
    expect(responseData['statusCode'], isNull);
    expect(profile.responseData.statusCode, isNull);
  });

  test('populating HttpClientRequestProfile.responseData.startTime', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['startTime'], isNull);
    expect(profile.responseData.startTime, isNull);

    profile.responseData.startTime = DateTime.parse('2024-03-21');

    expect(
      responseData['startTime'],
      DateTime.parse('2024-03-21').microsecondsSinceEpoch,
    );
    expect(profile.responseData.startTime, DateTime.parse('2024-03-21'));
  });

  test('HttpClientRequestProfile.responseData.startTime = null', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;

    profile.responseData.startTime = DateTime.parse('2024-03-21');
    expect(
      responseData['startTime'],
      DateTime.parse('2024-03-21').microsecondsSinceEpoch,
    );
    expect(profile.responseData.startTime, DateTime.parse('2024-03-21'));

    profile.responseData.startTime = null;
    expect(responseData['startTime'], isNull);
    expect(profile.responseData.startTime, isNull);
  });

  test('populating HttpClientRequestProfile.responseData.endTime', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['endTime'], isNull);
    expect(profile.responseData.endTime, isNull);

    await profile.responseData.close(DateTime.parse('2024-03-23'));

    expect(
      responseData['endTime'],
      DateTime.parse('2024-03-23').microsecondsSinceEpoch,
    );
    expect(profile.responseData.endTime, DateTime.parse('2024-03-23'));
  });

  test('populating HttpClientRequestProfile.responseData.error', () async {
    final responseData = backingMap['responseData'] as Map<String, dynamic>;
    expect(responseData['error'], isNull);
    expect(profile.responseData.error, isNull);

    await profile.responseData.closeWithError('failed');

    expect(responseData['error'], 'failed');
    expect(profile.responseData.error, 'failed');
  });

  test('using HttpClientRequestProfile.responseData.bodySink', () async {
    final responseBodyBytes = backingMap['responseBodyBytes'] as List<int>;
    expect(responseBodyBytes, isEmpty);
    expect(profile.responseData.bodyBytes, isEmpty);

    profile.responseData.bodySink.add([1, 2, 3]);
    profile.responseData.bodySink.addError('this is an error');
    profile.responseData.bodySink.add([4, 5]);
    await profile.responseData.close();

    expect(responseBodyBytes, [1, 2, 3, 4, 5]);
    expect(profile.responseData.bodyBytes, [1, 2, 3, 4, 5]);
  });
}
