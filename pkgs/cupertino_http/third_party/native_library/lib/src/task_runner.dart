// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'target.dart';
import 'toolchain.dart';

/// Runs tasks.
class TaskRunner {
  final Logger logger;

  TaskRunner._({required this.logger});

  factory TaskRunner({
    Logger? logger,
    Level? logLevel,
  }) {
    return TaskRunner._(
      logger: logger ?? _defaultLogger(logLevel),
    );
  }

  static Logger _defaultLogger(Level? logLevel) {
    hierarchicalLoggingEnabled = true;
    final logger = Logger('TaskRunner');
    if (logLevel != null) {
      logger.level = logLevel;
    }
    logger.onRecord.listen((record) {
      var message = record.message;
      if (!message.endsWith('\n')) message += '\n';
      if (record.level.value < Level.SEVERE.value) {
        stdout.write(message);
      } else {
        stderr.write(message);
      }
    });
    return logger;
  }

  Future<void> run(Task task) async {
    try {
      await task.run(taskRunner: this);
    } on Exception {
      logger.severe('One or more builds failed, check logs.');
      rethrow;
    }
  }
}

abstract class Task {
  Future<void> run({TaskRunner? taskRunner});

  factory Task.parallel(Iterable<Task> tasks) => _ParallelTask(tasks);

  factory Task.serial(Iterable<Task> tasks) => _SerialTask(tasks);

  factory Task.async(Future<Task> Function() f) => _FutureTask(Future(f));

  factory Task.function(Future<void> Function({TaskRunner? taskRunner}) f) =>
      _FunctionTask(f);
}

class _ParallelTask implements Task {
  final Iterable<Task> tasks;

  _ParallelTask(this.tasks);

  Future<void> run({TaskRunner? taskRunner}) =>
      Future.wait(tasks.map((e) => e.run(taskRunner: taskRunner)));
}

class _SerialTask implements Task {
  final Iterable<Task> tasks;

  _SerialTask(this.tasks);

  Future<void> run({TaskRunner? taskRunner}) async {
    for (final task in tasks) {
      await task.run(taskRunner: taskRunner);
    }
  }
}

class _FutureTask implements Task {
  final Future<Task> future;

  _FutureTask(this.future);

  Future<void> run({TaskRunner? taskRunner}) async =>
      (await future).run(taskRunner: taskRunner);
}

class _FunctionTask implements Task {
  final Future<void> Function({TaskRunner? taskRunner}) f;

  _FunctionTask(this.f);

  Future<void> run({TaskRunner? taskRunner}) async => f(taskRunner: taskRunner);
}

class Log implements Task {
  final Level logLevel;
  final String message;

  Log.info(this.message) : logLevel = Level.INFO;

  Future<void> run({TaskRunner? taskRunner}) async =>
      taskRunner?.logger.log(logLevel, message);
}

class Delete implements Task {
  final Uri uri;

  Delete(this.uri);

  @override
  Future<void> run({TaskRunner? taskRunner}) async {
    final dir = Directory.fromUri(uri);
    if (await dir.exists()) {
      taskRunner?.logger.config('Deleting `${uri.toFilePath()}`.');
      await dir.delete(recursive: true);
    }
  }

  static Task multiple(Iterable<Uri> uris) {
    final urisOrdered = uris.toSet().toList()
      ..sort((Uri a, Uri b) => a.path.compareTo(b.path));
    return Task.parallel(urisOrdered.map((uri) => Delete(uri)));
  }
}

class EnsureExists implements Task {
  final Uri target;

  EnsureExists(this.target);

  @override
  Future<void> run({TaskRunner? taskRunner}) async {
    final targetDir = Directory.fromUri(target);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
  }
}

class Copy implements Task {
  final Uri source;
  final Uri target;

  Copy._(this.source, this.target);

  static Task multiple(Uri source, Uri target, Iterable<String> files) {
    final filesSorted = files.toSet().toList()..sort();
    return Task.serial([
      EnsureExists(target),
      Task.serial([
        for (final file in filesSorted)
          Copy._(source.resolve(file), target.resolve(file)),
      ])
    ]);
  }

  @override
  Future<void> run({TaskRunner? taskRunner}) async {
    final file = File.fromUri(source);
    if (!await file.exists()) {
      final message =
          "File not in expected location: '${source.toFilePath()}'.";
      taskRunner?.logger.severe(message);
      throw Exception(message);
    }
    taskRunner?.logger
        .info('Copying ${source.toFilePath()} to ${target.toFilePath()}.');
    await file.copy(target.toFilePath());
  }
}

/// Runs the process, does not capture the result, streams to stdout and stderr
/// based on logger settings.
///
/// Runs a process not capturing the output on stdout and stderr.
///
/// If [throwOnFailure], throws
class RunProcess implements Task {
  final List<String> arguments;
  final String executable;
  final Uri? workingDirectory;
  Map<String, String>? environment;
  final bool throwOnFailure;

  RunProcess._({
    required this.arguments,
    required this.executable,
    this.workingDirectory,
    this.environment,
    this.throwOnFailure = true,
  });

  factory RunProcess({
    required String executable,
    required List<String> arguments,
    Uri? workingDirectory,
    Map<String, String>? environment,
    bool throwOnFailure = true,
    bool useRosetta = false,
  }) {
    if (useRosetta && Target.current == Target.macOSArm64) {
      return RunProcess._(
        executable: 'arch',
        arguments: [
          '-x86_64',
          executable,
          ...arguments,
        ],
        workingDirectory: workingDirectory,
        environment: environment,
        throwOnFailure: throwOnFailure,
      );
    }
    return RunProcess._(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      throwOnFailure: throwOnFailure,
    );
  }

  /// Excluding [workingDirectory].
  String get commandString => [
        if (workingDirectory != null) '(cd ${workingDirectory!.path};',
        ...?environment?.entries.map((entry) => '${entry.key}=${entry.value}'),
        executable,
        ...arguments.map((a) => a.contains(' ') ? "'$a'" : a),
        if (workingDirectory != null) ')',
      ].join(' ');

  @override
  Future<void> run({TaskRunner? taskRunner}) async {
    final workingDirectoryString = workingDirectory?.toFilePath();

    taskRunner?.logger.info('Running `$commandString`.');
    final process = await Process.start(executable, arguments,
            runInShell: true,
            includeParentEnvironment: true,
            workingDirectory: workingDirectoryString,
            environment: environment)
        .then((process) {
      process.stdout
          .transform(utf8.decoder)
          .forEach((s) => taskRunner?.logger.fine('  $s'));
      process.stderr
          .transform(utf8.decoder)
          .forEach((s) => taskRunner?.logger.severe('  $s'));
      return process;
    });
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final message =
          'Command `$commandString` failed with exit code $exitCode.';
      taskRunner?.logger.severe(message);
      if (throwOnFailure) {
        throw Exception(message);
      }
    }
    taskRunner?.logger.fine('Command `$commandString` done.');
  }
}

/// Builds (non-fat) binaries.
class CMakeBuild implements Task {
  final Uri srcUri;
  final Uri buildUri;
  final Uri? targetUri;
  final Target target;
  final List<String> dynamicLibraryNames;
  final List<String> staticLibraryNames;
  final List<String> executableNames;
  final String? codeSignIdentity;

  late final Task _implementation;

  CMakeBuild({
    required this.srcUri,
    required this.buildUri,
    this.targetUri,
    required this.target,
    this.dynamicLibraryNames = const [],
    this.staticLibraryNames = const [],
    this.executableNames = const [],
    this.codeSignIdentity,
  }) {
    if (target.iOSSdk == IOSSdk.iPhoneOs && codeSignIdentity == null) {
      throw Exception('No code signing identity provided for iOS device build. '
          'Pass --code-sign-identity or CODE_SIGN_IDENTITY. '
          'Find your code signing identity with '
          '`security find-identity -v -p codesigning`.');
    }

    _implementation = Task.async(() async {
      return Task.serial([
        RunProcess(
          useRosetta: true,
          executable: (await cmake).path,
          arguments: [
            '-S',
            srcUri.toFilePath(),
            '-B',
            buildUri.toFilePath(),
            if (target.os == OS.android) ...[
              '-DCMAKE_SYSTEM_NAME=Android',
              '-DCMAKE_SYSTEM_VERSION=28',
              '-DANDROID_PLATFORM=28',
              '-DCMAKE_ANDROID_ARCH_ABI=${target.architecture.cmakeAndroid}',
              if ((await androidNdk).version == null ||
                  (await androidNdk).version! < SemanticVersion(20))
                '-DCMAKE_ANDROID_NDK=${(await androidNdk).path}',
              if ((await androidNdk).version != null &&
                  (await androidNdk).version! >= SemanticVersion(20)) ...[
                '-DCMAKE_TOOLCHAIN_FILE=${(await androidNdk).path}build/cmake/android.toolchain.cmake',
              ]
            ],
            if (Target.current == Target.windowsX64) ...[
              '-GNinja',
              '-DCMAKE_MAKE_PROGRAM=${(await ninja).path}',
            ],
            if (target == Target.windowsX64)
              '-DCMAKE_C_COMPILER=${(await clang).path}',
            if (target == Target.windowsIA32) ...[
              '-DCMAKE_C_FLAGS=-m32',
            ],
            if (target == Target.linuxIA32)
              '-DCMAKE_C_COMPILER=i686-linux-gnu-gcc',
            if (target == Target.linuxArm)
              '-DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc',
            if (target == Target.linuxArm64)
              '-DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc',
            if (target.os == OS.iOS) ...[
              '-GXcode',
              '-DCMAKE_SYSTEM_NAME=iOS',
              '-DCMAKE_OSX_DEPLOYMENT_TARGET=10.0',
              '-DCMAKE_INSTALL_PREFIX=`pwd`/_install',
              '-DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO',
              '-DCMAKE_IOS_INSTALL_COMBINED=YES',
            ],
            if (target.os == OS.iOS || target.os == OS.macOS) ...[
              '-DCMAKE_OSX_ARCHITECTURES=${target.architecture.cmakeOsx}',
            ],
            if (target.iOSSdk == IOSSdk.iPhoneOs &&
                codeSignIdentity != null) ...[
              '-DCODE_SIGN_IDENTITY=$codeSignIdentity',
            ]
          ],
        ),
        RunProcess(
          useRosetta: true,
          executable: (await cmake).path,
          arguments: [
            '--build',
            buildUri.toFilePath(),
            '--target',
            ...dynamicLibraryNames,
            ...staticLibraryNames,
            ...executableNames,
            if (target.os == OS.iOS) ...[
              '--',
              '-sdk',
              target.iOSSdk!.xcodebuildSdk,
            ],
          ],
        ),
        if (targetUri != null)
          Copy.multiple(
            builtUri,
            targetUri!,
            [
              ...dynamicLibraryNames.map((n) => target.os.dylibFileName(n)),
              ...staticLibraryNames.map((n) => target.os.staticlibFileName(n)),
              ...executableNames.map((n) => target.os.executableFileName(n)),
            ],
          ),
      ]);
    });
  }

  /// Most compilers build into the target directory, but some move built
  /// artifacts into subfolders.
  Uri get builtUri {
    if (target.os == OS.iOS) {
      return buildUri.resolve('Debug-${target.iOSSdk!.xcodebuildSdk}/');
    }

    return buildUri;
  }

  @override
  Future<void> run({TaskRunner? taskRunner}) =>
      _implementation.run(taskRunner: taskRunner);
}

class Lipo implements Task {
  final List<Uri> srcUris;
  final Uri targetUri;

  late final Task _implementation;

  Lipo({
    required this.srcUris,
    required this.targetUri,
  }) {
    _implementation = Task.serial([
      RunProcess(
        executable: 'lipo',
        arguments: [
          '-create',
          for (final uri in srcUris) uri.toFilePath(),
          '-output',
          targetUri.toFilePath(),
        ],
        useRosetta: true,
      ),
    ]);
  }

  @override
  Future<void> run({TaskRunner? taskRunner}) =>
      _implementation.run(taskRunner: taskRunner);
}

class XCFramework implements Task {
  final List<Uri> srcUris;
  final Uri targetUri;

  late final Task _implementation;

  XCFramework({
    required this.srcUris,
    required this.targetUri,
  }) {
    _implementation = Task.serial([
      RunProcess(
        executable: 'xcodebuild',
        arguments: [
          '-create-xcframework',
          for (final uri in srcUris) ...[
            '-library',
            uri.toFilePath(),
          ],
          '-output',
          targetUri.toFilePath(),
        ],
        useRosetta: true,
      ),
    ]);
  }

  @override
  Future<void> run({TaskRunner? taskRunner}) =>
      _implementation.run(taskRunner: taskRunner);
}
