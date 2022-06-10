// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Builds the "cupertinohttp" Objective-C helper library used by cupertinohttp.
///
/// Build the library with:
/// ```
///   dart bin/setup.dart build
/// ```

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:native_library/native_library.dart';

const sharedLibraryName = 'cupertinohttp';
const packageName = 'cupertinohttp';
final srcUri = packageLocation(packageName).resolve('src/');

Uri buildUri(Abi abi) => sharedLibrariesLocationBuilt(packageName, abi: abi);
final _logger = Logger(packageName);

void main(List<String> args) async {
  final arguments = argParser.parse(args);
  final command = arguments.command;
  if (argParser.printHelp(arguments) || command == null) {
    return;
  }
  Logger.root.level = arguments.logLevel;
  Logger.root.onRecord.listen((record) {
    var message = record.message;
    if (!message.endsWith('\n')) message += '\n';
    if (record.level.value < Level.SEVERE.value) {
      stdout.write(message);
    } else {
      stderr.write(message);
    }
  });
  final abis = arguments.abis;
  switch (command.name) {
    case 'build':
      if (command['clean'] == true) {
        await clean(abis);
      }
      _logger.info('Building for $abis.');
      try {
        await Future.wait(abis.map(build));
      } on Exception {
        _logger.severe('One or more builds failed, check logs.');
        rethrow;
      }
      break;
    case 'clean':
      await clean(abis);
      break;
  }
}

Future<void> build(Abi abi) async {
  if (abi == Abi.current || abi == windowsIA32 || abi == linuxIA32) {
    return cmakeBuildSingleArch(abi);
  }
  _logger.severe(
      "Cross compilation from '${Abi.current}' to '$abi' not yet implemented.");
}

/// Builds (non-fat) binaries.
///
/// On iOS, assumes arm64 is building for device and x64 is building for
/// simulator.
Future<void> cmakeBuildSingleArch(Abi abi) async {
  await runProcess(
    (await cmake).path,
    [
      '-S',
      srcUri.toFilePath(),
      '-B',
      buildUri(abi).toFilePath(),
      if (Abi.current == windowsX64) ...[
        '-GNinja',
        '-DCMAKE_MAKE_PROGRAM=${(await ninja).path}',
      ],
      if (abi == windowsX64) '-DCMAKE_C_COMPILER=${(await clang).path}',
    ],
  );
  await runProcess(
    (await cmake).path,
    [
      '--build',
      buildUri(abi).toFilePath(),
      '--target',
      sharedLibraryName,
      if (abi.os == OS.iOS) ...[
        '--',
        '-sdk',
        abi.iOSSdk!.xcodebuildSdk,
      ],
    ],
  );
}

Future<void> runProcess(String executable, List<String> arguments) async {
  final commandString = [executable, ...arguments].join(' ');
  _logger.config('Running `$commandString`.');
  final process = await Process.start(
    executable,
    arguments,
    runInShell: true,
    includeParentEnvironment: true,
  ).then((process) {
    process.stdout.transform(utf8.decoder).forEach(_logger.fine);
    process.stderr.transform(utf8.decoder).forEach(_logger.severe);
    return process;
  });
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    final message = 'Command `$commandString` failed with exit code $exitCode.';
    _logger.severe(message);
    throw Exception(message);
  }
  _logger.fine('Command `$commandString` done.');
}

Future<void> clean(List<Abi> abis) async {
  _logger.info('Deleting built artifacts for $abis.');
  final paths = {
    for (final abi in abis) ...[
      buildUri(abi),
    ],
  }.toList()
    ..sort((Uri a, Uri b) => a.path.compareTo(b.path));
  await Future.wait(paths.map((path) async {
    _logger.config('Deleting `${path.toFilePath()}`.');
    final dir = Directory.fromUri(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }));
}
