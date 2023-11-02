// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:http_profile/http_profile.dart';
import 'package:test/test.dart';

void main() {
  test('profiling enabled', () async {
    HttpClientRequestProfile.profilingEnabled = true;
    expect(HttpClient.enableTimelineLogging, true);
    expect(HttpClientRequestProfile.profile(), isNotNull);
  });

  test('profiling disabled', () async {
    HttpClientRequestProfile.profilingEnabled = false;
    expect(HttpClient.enableTimelineLogging, false);
    expect(HttpClientRequestProfile.profile(), isNull);
  });
}
