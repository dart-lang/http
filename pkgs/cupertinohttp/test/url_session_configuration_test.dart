// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:cupertinohttp/cupertinohttp.dart';

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
          Duration(seconds: 15, microseconds: 23);
      expect(config.timeoutIntervalForRequest,
          Duration(seconds: 15, microseconds: 23));
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
