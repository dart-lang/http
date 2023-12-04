// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test/test.dart';

/// Make a HTTP request using the given configuration and return the headers
/// received by the server.
Future<Map<String, List<String>>> sentHeaders(
    URLSessionConfiguration config) async {
  final session = URLSession.sessionWithConfiguration(config);
  final headers = <String, List<String>>{};
  final server = (await HttpServer.bind('localhost', 0))
    ..listen((request) async {
      request.headers.forEach((k, v) => headers[k] = v);
      await request.drain<void>();
      request.response.headers.set('Content-Type', 'text/plain');
      request.response.write('Hello World');
      await request.response.close();
    });

  final task = session.dataTaskWithRequest(URLRequest.fromUrl(
      Uri(scheme: 'http', host: 'localhost', port: server.port)))
    ..resume();
  while (task.state != URLSessionTaskState.urlSessionTaskStateCompleted) {
    await pumpEventQueue();
  }

  await server.close();
  return headers;
}

void testProperties(URLSessionConfiguration config) {
  group('properties', () {
    test('allowsCellularAccess', () {
      config.allowsCellularAccess = true;
      expect(config.allowsCellularAccess, true);
      config.allowsCellularAccess = false;
      expect(config.allowsCellularAccess, false);
    });
    test('allowsConstrainedNetworkAccess', () {
      config.allowsConstrainedNetworkAccess = true;
      expect(config.allowsConstrainedNetworkAccess, true);
      config.allowsConstrainedNetworkAccess = false;
      expect(config.allowsConstrainedNetworkAccess, false);
    });
    test('allowsExpensiveNetworkAccess', () {
      config.allowsExpensiveNetworkAccess = true;
      expect(config.allowsExpensiveNetworkAccess, true);
      config.allowsExpensiveNetworkAccess = false;
      expect(config.allowsExpensiveNetworkAccess, false);
    });
    test('discretionary', () {
      config.discretionary = true;
      expect(config.discretionary, true);
      config.discretionary = false;
      expect(config.discretionary, false);
    });
    test('httpAdditionalHeaders', () async {
      expect(config.httpAdditionalHeaders, isNull);

      config.httpAdditionalHeaders = {
        'User-Agent': 'My Client',
        'MyHeader': 'myvalue'
      };
      expect(config.httpAdditionalHeaders,
          {'User-Agent': 'My Client', 'MyHeader': 'myvalue'});
      final headers = await sentHeaders(config);
      expect(headers, containsPair('user-agent', ['My Client']));
      expect(headers, containsPair('myheader', ['myvalue']));

      config.httpAdditionalHeaders = null;
      expect(config.httpAdditionalHeaders, isNull);
    });
    test('httpCookieAcceptPolicy', () {
      config.httpCookieAcceptPolicy =
          HTTPCookieAcceptPolicy.httpCookieAcceptPolicyAlways;
      expect(config.httpCookieAcceptPolicy,
          HTTPCookieAcceptPolicy.httpCookieAcceptPolicyAlways);
      config.httpCookieAcceptPolicy =
          HTTPCookieAcceptPolicy.httpCookieAcceptPolicyNever;
      expect(config.httpCookieAcceptPolicy,
          HTTPCookieAcceptPolicy.httpCookieAcceptPolicyNever);
    });
    test('httpMaximumConnectionsPerHost', () {
      config.httpMaximumConnectionsPerHost = 6;
      expect(config.httpMaximumConnectionsPerHost, 6);
      config.httpMaximumConnectionsPerHost = 23;
      expect(config.httpMaximumConnectionsPerHost, 23);
    });
    test('httpShouldSetCookies', () {
      config.httpShouldSetCookies = true;
      expect(config.httpShouldSetCookies, true);
      config.httpShouldSetCookies = false;
      expect(config.httpShouldSetCookies, false);
    });
    test('httpShouldUsePipelining', () {
      config.httpShouldUsePipelining = true;
      expect(config.httpShouldUsePipelining, true);
      config.httpShouldUsePipelining = false;
      expect(config.httpShouldUsePipelining, false);
    });
    test('multipathServiceType', () {
      expect(config.multipathServiceType,
          URLSessionMultipathServiceType.multipathServiceTypeNone);
      config.multipathServiceType =
          URLSessionMultipathServiceType.multipathServiceTypeAggregate;
      expect(config.multipathServiceType,
          URLSessionMultipathServiceType.multipathServiceTypeAggregate);
      config.multipathServiceType =
          URLSessionMultipathServiceType.multipathServiceTypeNone;
      expect(config.multipathServiceType,
          URLSessionMultipathServiceType.multipathServiceTypeNone);
    });
    test('networkServiceType', () {
      expect(config.networkServiceType,
          URLRequestNetworkService.networkServiceTypeDefault);
      config.networkServiceType =
          URLRequestNetworkService.networkServiceTypeResponsiveData;
      expect(config.networkServiceType,
          URLRequestNetworkService.networkServiceTypeResponsiveData);
      config.networkServiceType =
          URLRequestNetworkService.networkServiceTypeDefault;
      expect(config.networkServiceType,
          URLRequestNetworkService.networkServiceTypeDefault);
    });
    test('requestCachePolicy', () {
      config.requestCachePolicy = URLRequestCachePolicy.returnCacheDataDontLoad;
      expect(config.requestCachePolicy,
          URLRequestCachePolicy.returnCacheDataDontLoad);
      config.requestCachePolicy =
          URLRequestCachePolicy.reloadIgnoringLocalCacheData;
      expect(config.requestCachePolicy,
          URLRequestCachePolicy.reloadIgnoringLocalCacheData);
    });
    test('sessionSendsLaunchEvents', () {
      config.sessionSendsLaunchEvents = true;
      expect(config.sessionSendsLaunchEvents, true);
      config.sessionSendsLaunchEvents = false;
      expect(config.sessionSendsLaunchEvents, false);
    });
    test('shouldUseExtendedBackgroundIdleMode', () {
      config.shouldUseExtendedBackgroundIdleMode = true;
      expect(config.shouldUseExtendedBackgroundIdleMode, true);
      config.shouldUseExtendedBackgroundIdleMode = false;
      expect(config.shouldUseExtendedBackgroundIdleMode, false);
    });
    test('timeoutIntervalForRequest', () {
      config.timeoutIntervalForRequest =
          const Duration(seconds: 15, microseconds: 23);
      expect(config.timeoutIntervalForRequest,
          const Duration(seconds: 15, microseconds: 23));
    });
    test('waitsForConnectivity', () {
      config.waitsForConnectivity = true;
      expect(config.waitsForConnectivity, true);
      config.waitsForConnectivity = false;
      expect(config.waitsForConnectivity, false);
    });
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('backgroundSession', () {
    final config = URLSessionConfiguration.backgroundSession('myid');

    testProperties(config);
    config.toString(); // Just verify that there is no crash.
  });

  group('defaultSessionConfiguration', () {
    final config = URLSessionConfiguration.defaultSessionConfiguration();

    testProperties(config);
    config.toString(); // Just verify that there is no crash.
  });

  group('ephemeralSessionConfiguration', () {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration();

    testProperties(config);
    config.toString(); // Just verify that there is no crash.
  });
}
