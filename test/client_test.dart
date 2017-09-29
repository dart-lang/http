// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:http/http.dart';

import 'client.dart'
    if (dart.library.io) 'hybrid/client_io.dart'
    if (dart.library.html) 'hybrid/client_html.dart';
import 'utils.dart';

void main() {
  group('client', () {
    // The server url of the spawned server
    var serverUrl;

    setUp(() async {
      var channel = spawnHybridUri('hybrid/server.dart');
      serverUrl = Uri.parse(await channel.stream.first);
    });

    test('head', () async {
      var response = await platformClient().head(serverUrl);
      var body = await response.readAsString();

      expect(response.statusCode, equals(200));
      expect(body, equals(''));
    });

    test('get', () async {
      var response = await platformClient().get(serverUrl, headers: {
        'x-random-header': 'Value',
        'x-other-header': 'Other Value',
        'User-Agent': userAgent()
      });
      var body = await response.readAsString();

      expect(response.statusCode, equals(200));
      expect(
          body,
          parse(equals({
            'method': 'GET',
            'path': '/',
            'headers': {
              'user-agent': [userAgent()],
              'x-random-header': ['Value'],
              'x-other-header': ['Other Value']
            }
          })));
    });

    test('post with string', () async {
      var response = await platformClient().post(
        serverUrl,
        'request body',
        headers: {
          'x-random-header': 'Value',
          'x-other-header': 'Other Value',
          'User-Agent': userAgent()
        },
      );
      var body = await response.readAsString();

      expect(response.statusCode, equals(200));
      expect(
          body,
          parse(equals({
            'method': 'POST',
            'path': '/',
            'headers': {
              'content-type': ['text/plain; charset=utf-8'],
              'content-length': ['12'],
              'user-agent': [userAgent()],
              'x-random-header': ['Value'],
              'x-other-header': ['Other Value']
            },
            'body': 'request body'
          })));
    });

    test('post with bytes', () async {
      var response = await platformClient().post(
        serverUrl,
        [104, 101, 108, 108, 111],
        headers: {
          'x-random-header': 'Value',
          'x-other-header': 'Other Value',
          'User-Agent': userAgent()
        },
      );
      var body = await response.readAsString();

      expect(response.statusCode, equals(200));
      expect(
          body,
          parse(equals({
            'method': 'POST',
            'path': '/',
            'headers': {
              'content-length': ['5'],
              'user-agent': [userAgent()],
              'x-random-header': ['Value'],
              'x-other-header': ['Other Value']
            },
            'body': [104, 101, 108, 108, 111]
          })));
    });

    test('post with fields', () async {
      var response = await platformClient().post(
        serverUrl,
        {'some-field': 'value', 'other-field': 'other value'},
        headers: {
          'x-random-header': 'Value',
          'x-other-header': 'Other Value',
          'User-Agent': userAgent()
        },
      );
      var body = await response.readAsString();

      expect(response.statusCode, equals(200));
      expect(
          body,
          parse(equals({
            'method': 'POST',
            'path': '/',
            'headers': {
              'content-type': [
                'application/x-www-form-urlencoded; charset=utf-8'
              ],
              'content-length': ['40'],
              'user-agent': [userAgent()],
              'x-random-header': ['Value'],
              'x-other-header': ['Other Value']
            },
            'body': 'some-field=value&other-field=other+value'
          })));
    });

    test('put with string', () async {
      var response = await platformClient().put(
        serverUrl,
        'request body',
        headers: {
          'x-random-header': 'Value',
          'x-other-header': 'Other Value',
          'User-Agent': userAgent()
        },
      );
      var body = await response.readAsString();

      expect(response.statusCode, equals(200));
      expect(
          body,
          parse(equals({
            'method': 'PUT',
            'path': '/',
            'headers': {
              'content-type': ['text/plain; charset=utf-8'],
              'content-length': ['12'],
              'user-agent': [userAgent()],
              'x-random-header': ['Value'],
              'x-other-header': ['Other Value']
            },
            'body': 'request body'
          })));
    });

    test('put with bytes', () async {
      var response = await platformClient().put(
        serverUrl,
        [104, 101, 108, 108, 111],
        headers: {
          'x-random-header': 'Value',
          'x-other-header': 'Other Value',
          'User-Agent': userAgent()
        },
      );
      var body = await response.readAsString();

      expect(response.statusCode, equals(200));
      expect(
          body,
          parse(equals({
            'method': 'PUT',
            'path': '/',
            'headers': {
              'content-length': ['5'],
              'user-agent': [userAgent()],
              'x-random-header': ['Value'],
              'x-other-header': ['Other Value']
            },
            'body': [104, 101, 108, 108, 111]
          })));
    });

    test('put with fields', () async {
      var response = await platformClient().put(
        serverUrl,
        {'some-field': 'value', 'other-field': 'other value'},
        headers: {
          'x-random-header': 'Value',
          'x-other-header': 'Other Value',
          'User-Agent': userAgent()
        },
      );
      var body = await response.readAsString();

      expect(response.statusCode, equals(200));
      expect(
          body,
          parse(equals({
            'method': 'PUT',
            'path': '/',
            'headers': {
              'content-type': [
                'application/x-www-form-urlencoded; charset=utf-8'
              ],
              'content-length': ['40'],
              'user-agent': [userAgent()],
              'x-random-header': ['Value'],
              'x-other-header': ['Other Value']
            },
            'body': 'some-field=value&other-field=other+value'
          })));
    });

    test('patch with string', () async {
      var response = await platformClient().patch(
        serverUrl,
        'request body',
        headers: {
          'x-random-header': 'Value',
          'x-other-header': 'Other Value',
          'User-Agent': userAgent()
        },
      );
      var body = await response.readAsString();

      expect(response.statusCode, equals(200));
      expect(
          body,
          parse(equals({
            'method': 'PATCH',
            'path': '/',
            'headers': {
              'content-type': ['text/plain; charset=utf-8'],
              'content-length': ['12'],
              'user-agent': [userAgent()],
              'x-random-header': ['Value'],
              'x-other-header': ['Other Value']
            },
            'body': 'request body'
          })));
    });

    test('patch with bytes', () async {
      var response = await platformClient().patch(
        serverUrl,
        [104, 101, 108, 108, 111],
        headers: {
          'x-random-header': 'Value',
          'x-other-header': 'Other Value',
          'User-Agent': userAgent()
        },
      );
      var body = await response.readAsString();

      expect(response.statusCode, equals(200));
      expect(
          body,
          parse(equals({
            'method': 'PATCH',
            'path': '/',
            'headers': {
              'content-length': ['5'],
              'user-agent': [userAgent()],
              'x-random-header': ['Value'],
              'x-other-header': ['Other Value']
            },
            'body': [104, 101, 108, 108, 111]
          })));
    });

    test('patch with fields', () async {
      var response = await platformClient().patch(
        serverUrl,
        {'some-field': 'value', 'other-field': 'other value'},
        headers: {
          'x-random-header': 'Value',
          'x-other-header': 'Other Value',
          'User-Agent': userAgent()
        },
      );
      var body = await response.readAsString();

      expect(response.statusCode, equals(200));
      expect(
          body,
          parse(equals({
            'method': 'PATCH',
            'path': '/',
            'headers': {
              'content-type': [
                'application/x-www-form-urlencoded; charset=utf-8'
              ],
              'content-length': ['40'],
              'user-agent': [userAgent()],
              'x-random-header': ['Value'],
              'x-other-header': ['Other Value']
            },
            'body': 'some-field=value&other-field=other+value'
          })));
    });

    test('delete', () async {
      var response = await platformClient().delete(serverUrl, headers: {
        'x-random-header': 'Value',
        'x-other-header': 'Other Value',
        'User-Agent': userAgent()
      });
      var body = await response.readAsString();

      expect(response.statusCode, equals(200));
      expect(
          body,
          parse(equals({
            'method': 'DELETE',
            'path': '/',
            'headers': {
              'content-length': ['0'],
              'user-agent': [userAgent()],
              'x-random-header': ['Value'],
              'x-other-header': ['Other Value']
            }
          })));
    });

    test('read', () async {
      var body = await platformClient().read(serverUrl, headers: {
        'x-random-header': 'Value',
        'x-other-header': 'Other Value',
        'User-Agent': userAgent()
      });

      expect(
          body,
          parse(equals({
            'method': 'GET',
            'path': '/',
            'headers': {
              'user-agent': [userAgent()],
              'x-random-header': ['Value'],
              'x-other-header': ['Other Value']
            }
          })));
    });

    test('read throws an error for a 4** status code', () async {
      expect(() => platformClient().read(serverUrl.resolve('/error')),
          throwsClientException());
    });

    test('readBytes', () async {
      var body = await platformClient().readBytes(serverUrl, headers: {
        'x-random-header': 'Value',
        'x-other-header': 'Other Value',
        'User-Agent': userAgent()
      });

      expect(
          new String.fromCharCodes(body),
          parse(equals({
            'method': 'GET',
            'path': '/',
            'headers': {
              'user-agent': [userAgent()],
              'x-random-header': ['Value'],
              'x-other-header': ['Other Value']
            }
          })));
    });

    test('readBytes throws an error for a 4** status code', () async {
      expect(() => platformClient().readBytes(serverUrl.resolve('/error')),
          throwsClientException());
    });
  });
}
