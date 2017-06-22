// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:http/http.dart';
import 'package:test/test.dart';
// \TODO REMOVE
import 'package:http/src/cascade.dart';

final Uri _uri = Uri.parse('dart:http');

Client _handlerClient(int statusCode, String body) =>
    new Client.handler((_) async => new Response(_uri, statusCode, body: body));

void main() {
  group('a cascade with several handlers', () {
    Client client;
    setUp(() {
      client = new Cascade().add(new Client.handler((request) async {
        var statusCode = request.headers['one'] == 'false' ? 404 : 200;

        return new Response(_uri, statusCode, body: 'handler 1');
      })).add(new Client.handler((request) async {
        var statusCode = request.headers['two'] == 'false' ? 404 : 200;

        return new Response(_uri, statusCode, body: 'handler 2');
      })).add(new Client.handler((request) async {
        var statusCode = request.headers['three'] == 'false' ? 404 : 200;
        return new Response(_uri, statusCode, body: 'handler 3');
      })).client;
    });

    test('the first response should be returned if it matches', () async {
      var response = await client.get(_uri);
      expect(response.statusCode, equals(200));
      expect(response.readAsString(), completion(equals('handler 1')));
    });

    test(
        "the second response should be returned if it matches and the first "
        "doesn't", () async {
      var request = new Request('GET', _uri, headers: {'one': 'false'});

      var response = await client.send(request);
      expect(response.statusCode, equals(200));
      expect(response.readAsString(), completion(equals('handler 2')));
    });

    test(
        "the third response should be returned if it matches and the first "
        "two don't", () async {
      var request =
          new Request('GET', _uri, headers: {'one': 'false', 'two': 'false'});

      var response = await client.send(request);
      expect(response.statusCode, equals(200));
      expect(response.readAsString(), completion(equals('handler 3')));
    });

    test('the third response should be returned if no response matches',
        () async {
      var request = new Request('GET', _uri,
          headers: {'one': 'false', 'two': 'false', 'three': 'false'});

      var response = await client.send(request);
      expect(response.statusCode, equals(404));
      expect(response.readAsString(), completion(equals('handler 3')));
    });
  });

  test('a 404 response triggers a cascade by default', () async {
    var client = new Cascade()
        .add(_handlerClient(404, 'handler 1'))
        .add(_handlerClient(200, 'handler 2'))
        .client;

    var response = await client.get(_uri);
    expect(response.statusCode, equals(200));
    expect(response.readAsString(), completion(equals('handler 2')));
  });

  test('a 405 response triggers a cascade by default', () async {
    var client = new Cascade()
        .add(_handlerClient(405, ''))
        .add(_handlerClient(200, 'handler 2'))
        .client;

    var response = await client.get(_uri);
    expect(response.statusCode, equals(200));
    expect(response.readAsString(), completion(equals('handler 2')));
  });

  test('[statusCodes] controls which statuses cause cascading', () async {
    var client = new Cascade(statusCodes: [302, 403])
        .add(_handlerClient(302, '/'))
        .add(_handlerClient(403, 'handler 2'))
        .add(_handlerClient(404, 'handler 3'))
        .add(_handlerClient(200, 'handler 4'))
        .client;

    var response = await client.get(_uri);
    expect(response.statusCode, equals(404));
    expect(response.readAsString(), completion(equals('handler 3')));
  });

  test('[shouldCascade] controls which responses cause cascading', () async {
    var client =
        new Cascade(shouldCascade: (response) => response.statusCode % 2 == 1)
            .add(_handlerClient(301, '/'))
            .add(_handlerClient(403, 'handler 2'))
            .add(_handlerClient(404, 'handler 3'))
            .add(_handlerClient(200, 'handler 4'))
            .client;

    var response = await client.get(_uri);
    expect(response.statusCode, equals(404));
    expect(response.readAsString(), completion(equals('handler 3')));
  });

  test('Cascade calls close on all clients', () {
    int accessLocation = 0;

    var client = new Cascade()
        .add(new Client.handler((_) async => null, onClose: () {
          expect(accessLocation, 2);
          accessLocation = 3;
        }))
        .add(new Client.handler((_) async => null, onClose: () {
          expect(accessLocation, 1);
          accessLocation = 2;
        }))
        .add(new Client.handler((_) async => null, onClose: () {
          expect(accessLocation, 0);
          accessLocation = 1;
        }))
        .client;

    client.close();
    expect(accessLocation, 3);
  });

  group('errors', () {
    test('getting the handler for an empty cascade fails', () {
      expect(() => new Cascade().client, throwsStateError);
    });

    test('passing [statusCodes] and [shouldCascade] at the same time fails',
        () {
      expect(
          () =>
              new Cascade(statusCodes: [404, 405], shouldCascade: (_) => false),
          throwsArgumentError);
    });
  });
}
