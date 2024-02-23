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
/// 4. Change the name of `cronet_http.dart` to `cronet_http_embedded.dart`.
/// 5. Update all the imports from `package:cronet_http/cronet_http.dart` to
///    `package:cronet_http_embedded/cronet_http_embedded.dart`
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

late final String _scriptName;
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
// Finds the Google Play Services Cronet dependency line. For example:
// '    implementation "com.google.android.gms:play-services-cronet:18.0.1"'
final implementationRegExp = RegExp(
  '^\\s*implementation [\'"]'
  '$_gmsDependencyName'
  ':\\d+.\\d+.\\d+[\'"]',
  multiLine: true,
);

void main(List<String> args) async {
  final script = Platform.script.toFilePath();
  _scriptName = script.split(Platform.pathSeparator).last;
  _packageDirectory = Directory(
    Uri.directory(
      '${script.replaceAll(_scriptName, '')}'
      '..${Platform.pathSeparator}',
    ).toFilePath(),
  );
  final latestVersion = await _getLatestCronetVersion();
  updateBuildGradle(latestVersion);
  updateExampleBuildGradle();
  updatePubSpec();
  updateReadme();
  updateLibraryName();
  updateImports();
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

/// Update android/build.gradle.
void updateBuildGradle(String latestVersion) {
  final buildGradle = File('${_packageDirectory.path}/android/build.gradle');
  final gradleContent = buildGradle.readAsStringSync();
  final newImplementation = '$_embeddedDependencyName:$latestVersion';
  print('Updating ${buildGradle.path}: adding $newImplementation');
  final newGradleContent = gradleContent.replaceAll(
    implementationRegExp,
    '    implementation "$newImplementation"',
  );
  buildGradle.writeAsStringSync(newGradleContent);
}

/// Remove the cronet reference from ./example/android/app/build.gradle.
void updateExampleBuildGradle() {
  final buildGradle =
      File('${_packageDirectory.path}/example/android/app/build.gradle');
  final gradleContent = buildGradle.readAsStringSync();

  print('Updating ${buildGradle.path}: removing cronet reference');
  final newGradleContent = gradleContent.replaceAll(
    implementationRegExp,
    '    // NOTE: removed in package:cronet_http_embedded',
  );
  buildGradle.writeAsStringSync(newGradleContent);
}

/// Update pubspec.yaml and example/pubspec.yaml.
void updatePubSpec() {
  print('Updating pubspec.yaml');
  final fPubspec = File('${_packageDirectory.path}/pubspec.yaml');
  final yamlEditor = YamlEditor(fPubspec.readAsStringSync())
    ..update(['name'], _packageName)
    ..update(['description'], _packageDescription);
  fPubspec.writeAsStringSync(yamlEditor.toString());
  print('Updating example/pubspec.yaml');
  final examplePubspec = File('${_packageDirectory.path}/example/pubspec.yaml');
  final replaced = examplePubspec
      .readAsStringSync()
      .replaceAll('cronet_http:', 'cronet_http_embedded:');
  examplePubspec.writeAsStringSync(replaced);
}

/// Move README_EMBEDDED.md to replace README.md.
void updateReadme() {
  print('Updating README.md from README_EMBEDDED.md');
  File('${_packageDirectory.path}/README.md').deleteSync();
  File('${_packageDirectory.path}/README_EMBEDDED.md')
      .renameSync('${_packageDirectory.path}/README.md');
}

void updateImports() {
  print('Updating imports in Dart files');
  for (final file in _packageDirectory.listSync(recursive: true)) {
    if (file is File &&
        file.path.endsWith('.dart') &&
        !file.path.contains(_scriptName)) {
      final updatedSource = file.readAsStringSync().replaceAll(
            'package:cronet_http/cronet_http.dart',
            'package:cronet_http_embedded/cronet_http_embedded.dart',
          );
      file.writeAsStringSync(updatedSource);
    }
  }
}

void updateLibraryName() {
  print('Renaming cronet_http.dart to cronet_http_embedded.dart');
  File(
    '${_packageDirectory.path}/lib/cronet_http.dart',
  ).renameSync(
    '${_packageDirectory.path}/lib/cronet_http_embedded.dart',
  );
}
