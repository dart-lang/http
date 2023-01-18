// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

void main() async {
  final latestVersion = await _getLatestVersion();
  _writeImplementationToTheFile(latestVersion);
}

Future<String> _getLatestVersion() async {
  final url = Uri.https(
    'dl.google.com',
    'android/maven2/org/chromium/net/group-index.xml',
  );
  final response = await http.get(url);
  final parsedXml = XmlDocument.parse(response.body);
  final embeddedNode = parsedXml.children
      .singleWhere((e) => e is XmlElement)
      .children
      .singleWhere((e) => e is XmlElement && e.name.local == 'cronet-embedded');
  final stableVersionReg = RegExp(r'^(\d+).(\d+).(\d+)$');
  final versions = embeddedNode.attributes
      .singleWhere((e) => e.name.local == 'versions')
      .value
      .split(',')
      .where((e) => stableVersionReg.stringMatch(e) == e);
  return versions.last;
}

void _writeImplementationToTheFile(String latestVersion) {
  var dir = Directory.current;
  if (dir.path.endsWith('tool')) {
    dir = dir.parent;
  }
  // Update android/build.gradle
  final fBuildGradle = File('${dir.path}/android/build.gradle');
  final gradleContent = fBuildGradle.readAsStringSync();
  final implementationRegExp = RegExp(
    '^(\\s*)implementation [\'"]'
    'com.google.android.gms:play-services-cronet'
    ':(\\d+.\\d+.\\d+)[\'"]',
    multiLine: true,
  );
  final newGradleContent = gradleContent.replaceAll(
    implementationRegExp,
    '    implementation "org.chromium.net:cronet-embedded:$latestVersion"',
  );
  fBuildGradle.writeAsStringSync(newGradleContent);
  // Update pubspec.yaml
  final fPubspec = File('${dir.path}/pubspec.yaml');
  fPubspec.writeAsStringSync(
    fPubspec.readAsStringSync().replaceAll(
          RegExp(r'^name: cronet_http$'),
          'name: cronet_http_embedded',
        ),
  );
}
