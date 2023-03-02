// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The cronet_http directory is used to produce two packages:
/// - `cronet_http`, which uses the Google Play Services version of Cronet.
/// - `cronet_http_embedded`, which embeds Cronet.
///
/// The default configuration of this code is to use the
/// Google Play Services version of Cronet.
///
/// The script transforms the configuration into one that embeds Cronet by:
/// 1. Modifying the Gradle build file to reference the embedded Cronet.
/// 2. Modifying the *name* and *description* in `pubspec.yaml`.
/// 3. Replacing `README.md` with `README_EMBEDDED.md`.
///
/// After running this script, `flutter pub publish`
/// can be run to update package:cronet_http_embedded.
///
/// NOTE: This script modifies the above files in place.
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:yaml_edit/yaml_edit.dart';

late final Directory _packageDirectory;

const _gmsDependencyName = 'com.google.android.gms:play-services-cronet';
const _embeddedDependencyName = 'org.chromium.net:cronet-embedded';
const _packageName = 'cronet_http_embedded';
const _packageDescription = 'An Android Flutter plugin that '
    'provides access to the Cronet HTTP client. '
    'Identical to package:cronet_http except that it embeds Cronet '
    'rather than relying on Google Play Services.';
final _cronetVersionUri = Uri.https(
  'dl.google.com',
  'android/maven2/org/chromium/net/group-index.xml',
);

void main() async {
  if (Directory.current.path.endsWith('tool')) {
    _packageDirectory = Directory.current.parent;
  } else {
    _packageDirectory = Directory.current;
  }

  final latestVersion = await _getLatestCronetVersion();
  updateCronetDependency(latestVersion);
  updatePubSpec();
  updateReadme();
}

Future<String> _getLatestCronetVersion() async {
  final response = await http.get(_cronetVersionUri);
  final parsedXml = XmlDocument.parse(response.body);
  final embeddedNode = parsedXml.children
      .singleWhere((e) => e is XmlElement)
      .children
      .singleWhere((e) => e is XmlElement && e.name.local == 'cronet-embedded');
  final stableVersionReg = RegExp(r'^\d+.\d+.\d+$');
  final versions = embeddedNode.attributes
      .singleWhere((e) => e.name.local == 'versions')
      .value
      .split(',')
      .where((e) => stableVersionReg.stringMatch(e) == e);
  return versions.last;
}

/// Update android/build.gradle
void updateCronetDependency(String latestVersion) {
  final fBuildGradle = File('${_packageDirectory.path}/android/build.gradle');
  final gradleContent = fBuildGradle.readAsStringSync();
  final implementationRegExp = RegExp(
    '^\\s*implementation [\'"]'
    '$_gmsDependencyName'
    ':\\d+.\\d+.\\d+[\'"]',
    multiLine: true,
  );
  final newImplementation = '$_embeddedDependencyName:$latestVersion';
  print('Patching $newImplementation');
  final newGradleContent = gradleContent.replaceAll(
    implementationRegExp,
    '    implementation $newImplementation',
  );
  fBuildGradle.writeAsStringSync(newGradleContent);
}

/// Update pubspec.yaml
void updatePubSpec() {
  final fPubspec = File('${_packageDirectory.path}/pubspec.yaml');
  final yamlEditor = YamlEditor(fPubspec.readAsStringSync())
    ..update(['name'], _packageName)
    ..update(['description'], _packageDescription);
  fPubspec.writeAsStringSync(yamlEditor.toString());
}

/// Move README_EMBEDDED.md to replace README.md
void updateReadme() {
  File('${_packageDirectory.path}/README.md').deleteSync();
  File('${_packageDirectory.path}/README_EMBEDDED.md')
      .renameSync('${_packageDirectory.path}/README.md');
}
