// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:native_library/src/target.dart';
import 'package:logging/logging.dart';

/// Default [ArgParser] for command line tools for compiling native libraries.
///
/// It has built in support for dealing with [Target]s, logging [Level], common
/// commands for `build`ing and `clean`ing and displaying the help message.
final ArgParser argParser = () {
  final argParser = ArgParser();

  argParser.addFlag('help',
      help: 'Show additional diagnostic info.', negatable: false);

  argParser.addMultiOption(
    'arch',
    abbr: 'a',
    help: 'Target architectures to invoke the commands for. '
        'Selects all targets in the cross product with --os.',
    allowed: [...Architecture.values.map((e) => e.dartPlatform), 'all'],
    defaultsTo: [Target.current.architecture.dartPlatform],
  );

  argParser.addMultiOption(
    'os',
    abbr: 'o',
    help: 'Target OSes to invoke the commands for. '
        'Selects all targets in the cross product with --arch',
    allowed: [...OS.values.map((e) => e.dartPlatform), 'all'],
    defaultsTo: [Target.current.os.dartPlatform],
  );

  argParser.addMultiOption(
    'target',
    abbr: 't',
    help: 'Targets to invoke the commands for. Overrides --arch and --os.',
    allowed: [
      ...Target.current
          .supportedTargetTargets()
          .map((target) => target.toString()),
      'all'
    ],
    defaultsTo: [],
  );

  argParser.addOption('verbosity',
      allowed: Level.LEVELS.map((l) => l.name.toLowerCase()),
      defaultsTo: _defaultLevel.name.toLowerCase(),
      help: 'Verbosity level of logging to standard out.');

  argParser.addOption('code-sign-identity',
      help: 'The code signing identity to use for iOS device builds.');

  argParser.addFlag('verbose',
      abbr: 'v',
      help: "Equal to --verbosity ${_verboseLevel.name.toLowerCase()}. "
          'Overrides --verbosity and --silent.',
      negatable: false);

  argParser.addFlag('silent',
      abbr: 's',
      help: "Equal to --verbosity ${_silentLevel.name.toLowerCase()}. "
          'Overrides --verbosity.',
      negatable: false);

  argParser.addCommand(
      'build',
      ArgParser()
        ..addFlag('clean', help: 'Clean before building.', defaultsTo: false)
        ..addFlag('help',
            help: 'Show additional diagnostic info.', defaultsTo: false));

  argParser.addCommand('clean');

  return argParser;
}();

/// Extension on [ArgParser]s to automatically print help messages.
extension ArgParserRecursive on ArgParser {
  /// Recursively traverses commands to see if `--help` was passed.
  ///
  /// If [printForMissingCommand], then also prints help for if subcommands
  /// exist but are not passed in.
  ///
  /// Returns whether help was printed.
  bool printHelp(ArgResults results, {bool printForMissingCommand: true}) {
    final command = results.command;
    var printed = false;
    if (command != null) {
      printed |= commands[command.name]!.printHelp(command);
    }
    if ((options.containsKey('help') && results['help'] == true) ||
        (printForMissingCommand && commands.isNotEmpty && command == null)) {
      if (commands.isNotEmpty) {
        print('Supported commands are: ${commands.keys}');
      }
      print(usage);
      printed = true;
    }
    return printed;
  }
}

/// Helper methods that go together with [argParser].
extension NativeLibraryArgResults on ArgResults {
  /// The [Target]s passed in as argument.
  List<Target> get targets {
    final validTargets = Target.current.supportedTargetTargets();
    final targets = _allOrSpecified(this['target'] as List<String>,
        validTargets, (s) => Target.fromString(s));
    if (targets.isNotEmpty) {
      return targets.toList();
    }
    final oses = _allOrSpecified(
        this['os'] as List<String>, OS.values, (s) => OS.fromDartPlatform(s));
    final archs = _allOrSpecified(this['arch'] as List<String>,
        Architecture.values, (s) => Architecture.fromDartPlatform(s));
    return [
      for (final os in oses)
        for (final arch in archs)
          if (Target.isValid(os, arch)) Target(os, arch)
    ];
  }

  /// The logging [Level] requested in these arguments.
  ///
  /// `--verbose` is [Level.FINER] and overrides `--silent` and `--verbosity`.
  /// `--silent` is [Level.SEVERE] and overrides `--verbosity`.
  Level get logLevel {
    if (this['verbose'] == true) {
      return _verboseLevel;
    }
    if (this['silent'] == true) {
      return _silentLevel;
    }
    return Level.LEVELS
        .firstWhere((l) => l.name.toLowerCase() == this['verbosity']);
  }

  String? get codeSignIdentity {
    var result = this['code-sign-identity'] as String?;
    if (result != null) {
      return result;
    }
    result = Platform.environment['CODE_SIGN_IDENTITY'];
    return result;
  }
}

const Level _verboseLevel = Level.FINER;
const Level _silentLevel = Level.SEVERE;
const Level _defaultLevel = Level.INFO;

Iterable<T> _allOrSpecified<T>(
    List<String> list, Iterable<T> all, T Function(String) parseElement) {
  if (list.contains('all')) {
    return all;
  }
  return list.map(parseElement);
}
