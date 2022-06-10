import 'dart:io';

import 'package:args/args.dart';
import 'package:native_library/native_library.dart';

void main(List<String> args) async {
  final arguments = argParser.parse(args);
  if (arguments['help']) {
    printUsage();
    return;
  }

  final command = arguments.command;
  if (command == null) {
    printUsage();
    return;
  }

  switch (command.name) {
    case 'doctor':
      final result = await doctor();
      exit(result ? 0 : 1);
  }
}

void printUsage() {
  print('Supported commands are: ${argParser.commands.keys}');
  print(argParser.usage);
}

final ArgParser argParser = () {
  final argParser = ArgParser();

  argParser.addFlag('help', help: 'Show additional diagnostic info');

  argParser.addCommand('doctor');

  return argParser;
}();

bool _report(NativeTool tool) {
  const green = '\u001b[32m';
  const red = '\u001b[31m';
  const resetColor = '\u001B[39m';
  final okay = '$green[√]$resetColor';
  final error = '$red[✖]$resetColor';

  final uri = tool.uri;
  if (uri == null) {
    stderr.writeln("$error ${tool.name} not found. Paths searched:");
    if (tool.searchedOnPath) {
      stderr.writeln("     - If available on PATH.");
    }
    for (final uri in tool.searchedInUris) {
      stderr.writeln("     - ${uri.toFilePath()}");
    }
    if (tool.searchedInUris.isEmpty && !tool.searchedOnPath) {
      stderr.writeln("     - (none)");
    }
    return false;
  }
  final version = tool.version;
  final versionString = version != null ? ' $version' : '';
  stdout.writeln("$okay ${tool.name}$versionString: ${uri.toFilePath()}");
  return true;
}

Future<bool> doctor() async {
  final tools_ = await tools;
  tools_.forEach(_report);
  return !tools_.map((tool) => tool.isAvailable).contains(false);
}
