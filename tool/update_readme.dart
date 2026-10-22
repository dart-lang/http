// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Generates the package table in the root `README.md` from `pkgs/*/pubspec.yaml`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';

const _startMarker = '<!-- PKG_TABLE_START -->';
const _endMarker = '<!-- PKG_TABLE_END -->';
const _validateFlag = '--validate';

void main(List<String> args) {
  var validate = false;
  if (args.isNotEmpty) {
    if (args.length == 1 && args.single == _validateFlag) {
      validate = true;
    } else {
      stderr.writeln('Usage: dart tool/update_readme.dart [$_validateFlag]');
      exitCode = 64;
      return;
    }
  }

  final repoRoot = Directory('pkgs').existsSync()
      ? Directory.current
      : Directory.current.parent;
  final pkgsDir = Directory(p.join(repoRoot.path, 'pkgs'));
  if (!pkgsDir.existsSync()) {
    stderr.writeln('ERROR: Could not find pkgs/ directory at ${pkgsDir.path}');
    exitCode = 2;
    return;
  }

  final readmeFile = File(p.join(repoRoot.path, 'README.md'));
  if (!readmeFile.existsSync()) {
    stderr.writeln('ERROR: ${readmeFile.path} does not exist');
    exitCode = 2;
    return;
  }

  final newTable = _generatePackageTable(pkgsDir);
  _updateOrValidateSection(
    file: readmeFile,
    startMarker: _startMarker,
    endMarker: _endMarker,
    newContent: newTable,
    validate: validate,
  );
}

String _generatePackageTable(Directory pkgsDir) {
  final pkgDirs = pkgsDir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

  final buffer = StringBuffer()
    ..writeln('| Package | Description | Version |')
    ..writeln('|---|---|---|');

  for (final dir in pkgDirs) {
    final dirName = p.basename(dir.path);
    final pubspecFile = File(p.join(dir.path, 'pubspec.yaml'));
    final pubspec = Pubspec.parse(
      pubspecFile.readAsStringSync(),
      sourceUrl: pubspecFile.uri,
    );

    if (pubspec.name != dirName) {
      throw StateError(
        'Package directory name "$dirName" does not match pubspec name '
        '"${pubspec.name}".',
      );
    }

    final rawDescription = pubspec.description;
    if (rawDescription == null || rawDescription.trim().isEmpty) {
      throw StateError('Missing description in ${pubspecFile.path}.');
    }

    final description = rawDescription
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .join(' ')
        .replaceAll('|', r'\|');
    final badge = 'https://img.shields.io/pub/v/${pubspec.name}.svg';
    final pubUrl = 'https://pub.dev/packages/${pubspec.name}';
    final published = pubspec.publishTo == null;
    final versionCell = published ? '[![pub package]($badge)]($pubUrl)' : '—';

    buffer.writeln(
      '| [${pubspec.name}](pkgs/${pubspec.name}/) '
      '| $description '
      '| $versionCell |',
    );
  }

  return buffer.toString();
}

void _updateOrValidateSection({
  required File file,
  required String startMarker,
  required String endMarker,
  required String newContent,
  required bool validate,
}) {
  final content = file.readAsStringSync().replaceAll('\r\n', '\n');

  final startIndex = content.indexOf(startMarker);
  final endIndex = content.indexOf(endMarker);

  if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
    stderr.writeln(
      'ERROR: Could not find valid markers ($startMarker, $endMarker) '
      'in ${file.path}',
    );
    exitCode = 75;
    return;
  }

  final updatedContent =
      '${content.substring(0, startIndex + startMarker.length)}\n'
      '$newContent'
      '${content.substring(endIndex)}';

  if (validate) {
    if (content != updatedContent) {
      stderr.writeln(
        'ERROR: ${file.path} is out of sync with pkgs/*/pubspec.yaml.\n'
        'Run `dart tool/update_readme.dart` to update it.',
      );
      exitCode = 1;
    } else {
      print('${file.path} is up to date.');
    }
    return;
  }

  file.writeAsStringSync(updatedContent);
  print('Successfully updated ${file.path}');
}
