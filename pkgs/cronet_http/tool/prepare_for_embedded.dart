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

import 'package:yaml_edit/yaml_edit.dart';

late final Directory _packageDirectory;

// For the latest version, see:
// https://mvnrepository.com/artifact/org.chromium.net/cronet-embedded
const _cronetEmbeddedVersion = '113.5672.61';
const _gmsDependencyName = 'com.google.android.gms:play-services-cronet';
const _embeddedDependencyName = 'org.chromium.net:cronet-embedded';
const _packageName = 'cronet_http_embedded';
const _packageDescription = 'An Android Flutter plugin that '
    'provides access to the Cronet HTTP client. '
    'Identical to package:cronet_http except that it embeds Cronet '
    'rather than relying on Google Play Services.';
final implementationRegExp = RegExp(
  '^\\s*implementation [\'"]'
  '$_gmsDependencyName'
  ':\\d+.\\d+.\\d+[\'"]',
  multiLine: true,
);

void main(List<String> args) async {
  if (Directory.current.path.endsWith('tool')) {
    _packageDirectory = Directory.current.parent;
  } else {
    _packageDirectory = Directory.current;
  }

  updateCronetDependency(_cronetEmbeddedVersion);
  update2();
  updatePubSpec();
  updateReadme();
  updateLibraryName();
  updateImports();
}

/// Update android/build.gradle.
void updateCronetDependency(String latestVersion) {
  final fBuildGradle = File('${_packageDirectory.path}/android/build.gradle');
  final gradleContent = fBuildGradle.readAsStringSync();
  final newImplementation = '$_embeddedDependencyName:$latestVersion';
  print('Patching $newImplementation');
  final newGradleContent = gradleContent.replaceAll(
    implementationRegExp,
    '    implementation "$newImplementation"',
  );
  fBuildGradle.writeAsStringSync(newGradleContent);
}

void update2() {
  final fBuildGradle =
      File('${_packageDirectory.path}/example/android/app/build.gradle');
  final gradleContent = fBuildGradle.readAsStringSync();
  final newGradleContent = gradleContent.replaceAll(
    implementationRegExp,
    '',
  );
  fBuildGradle.writeAsStringSync(newGradleContent);
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
    if (file is File && file.path.endsWith('.dart')) {
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
