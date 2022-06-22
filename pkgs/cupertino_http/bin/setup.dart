// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:args/args.dart';

import 'package:native_library/native_library.dart';

const sharedLibraryName = 'cupertinohttp';
const packageName = 'cupertinohttp';
final srcUri = packageLocation(packageName).resolve('src/');
Uri targetUri(Target target) =>
    sharedLibrariesLocationBuilt(packageName, target: target);
Uri buildUri(Target target) => targetUri(target).resolve('out/');
void main(List<String> args) async {
  final arguments = argParser.parse(args);
  final command = arguments.command;
  if (argParser.printHelp(arguments) || command == null) {
    return;
  }
  final taskRunner = TaskRunner(logLevel: arguments.logLevel);
  final targets = arguments.targets;
  final task = Task.serial([
    if (command.name == 'build') ...[
      if (command['clean'] == true) ...[
        cleanTask(targets),
      ],
      Log.info('Building for $targets.'),
      buildTask(targets, arguments),
    ],
    if (command.name == 'clean') ...[
      cleanTask(targets),
    ],
  ]);
  await taskRunner.run(task);
}

Task buildTask(Iterable<Target> targets, ArgResults arguments) =>
    Task.parallel([
      for (final target in targets)
        CMakeBuild(
          srcUri: srcUri,
          buildUri: buildUri(target),
          targetUri: targetUri(target),
          target: target,
          dynamicLibraryNames: [sharedLibraryName],
          codeSignIdentity: arguments.codeSignIdentity,
        ),
    ]);

Task cleanTask(List<Target> targets) => Task.serial([
      Log.info('Deleting built artifacts for $targets.'),
      Delete.multiple([
        // [buildUri] is subfolder of [targetUri].
        ...targets.map(targetUri),
      ]),
    ]);
