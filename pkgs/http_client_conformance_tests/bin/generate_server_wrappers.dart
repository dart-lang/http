// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Generates the '*_server_vm.dart' and '*_server_web.dart' support files.
library;

import 'dart:core';
import 'dart:io';

import 'package:dart_style/dart_style.dart';

const vm = '''// Generated by generate_server_wrappers.dart. Do not edit.

import 'package:stream_channel/stream_channel.dart';

import '<server_file_placeholder>';

/// Starts the redirect test HTTP server in the same process.
Future<StreamChannel<Object?>> startServer() async {
  final controller = StreamChannelController<Object?>(sync: true);
  hybridMain(controller.foreign);
  return controller.local;
}
''';

const web = '''// Generated by generate_server_wrappers.dart. Do not edit.

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

/// Starts the redirect test HTTP server out-of-process.
Future<StreamChannel<Object?>> startServer() async => spawnHybridUri(Uri(
    scheme: 'package',
    path: 'http_client_conformance_tests/src/<server_file_placeholder>'));
''';

void main() async {
  final files = await Directory('lib/src').list().toList();
  final formatter = DartFormatter();

  files.where((file) => file.path.endsWith('_server.dart')).forEach((file) {
    final vmPath = file.path.replaceAll('_server.dart', '_server_vm.dart');
    File(vmPath).writeAsStringSync(formatter.format(vm.replaceAll(
        '<server_file_placeholder>', file.uri.pathSegments.last)));

    final webPath = file.path.replaceAll('_server.dart', '_server_web.dart');
    File(webPath).writeAsStringSync(formatter.format(web.replaceAll(
        '<server_file_placeholder>', file.uri.pathSegments.last)));
  });
}
