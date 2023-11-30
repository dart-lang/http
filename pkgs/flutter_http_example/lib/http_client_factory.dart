// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart';

const maxCacheSize = 2 * 1024 * 1024;

Client httpClient() {
  if (Platform.isAndroid) {
    final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: maxCacheSize,
        userAgent: 'Book Agent');
    return CronetClient.fromCronetEngine(engine);
  }
  if (Platform.isIOS || Platform.isMacOS) {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration()
      ..cache = URLCache.withCapacity(memoryCapacity: maxCacheSize);
    return CupertinoClient.fromSessionConfiguration(config);
  }
  return Client(); // Return the default client.
}
