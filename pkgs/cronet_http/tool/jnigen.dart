// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:jnigen/jnigen.dart';

void main(List<String> args) async {
  final packageRoot = Platform.script.resolve('../');
  final generator = JniGenerator(
    input: Input(
      classes: [
        'io.flutter.plugins.cronet_http.UrlRequestCallbackProxy',
        'java.io.IOException',
        'java.lang.Exception',
        'java.lang.Throwable',
        'java.net.URL',
        'java.util.concurrent.Executors',
        'org.chromium.net.CronetEngine',
        'org.chromium.net.DnsOptions',
        'org.chromium.net.CallbackException',
        'org.chromium.net.CronetException',
        'org.chromium.net.NetworkException',
        'org.chromium.net.QuicException',
        'org.chromium.net.UploadDataProviders',
        'org.chromium.net.UrlRequest',
        'org.chromium.net.UrlResponseInfo',
      ],
      androidSdk: AndroidSdk(
        addGradleDeps: true,
        androidExample: packageRoot.resolve('example/'),
      ),
    ),
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/src/jni/jni_bindings.dart'),
        structure: OutputStructure.singleFile,
      ),
    ),
  );
  await generator.generate();
}
