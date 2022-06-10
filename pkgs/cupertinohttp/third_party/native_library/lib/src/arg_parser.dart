import 'package:args/args.dart';
import 'package:native_library/src/abi.dart';
import 'package:logging/logging.dart';

/// Default [ArgParser] for command line tools for compiling native libraries.
///
/// It has built in support for dealing with [Abi]s, logging [Level], common
/// commands for `build`ing and `clean`ing and displaying the help message.
final ArgParser argParser = () {
  final argParser = ArgParser();

  argParser.addFlag('help',
      help: 'Show additional diagnostic info.', negatable: false);

  argParser.addMultiOption(
    'arch',
    abbr: 'a',
    help: 'Target architectures to invoke the commands for.',
    allowed: [...architectureStrings.values, 'all'],
    defaultsTo: [Abi.current.architecture.dartPlatform],
  );

  argParser.addMultiOption(
    'os',
    abbr: 'o',
    help: 'Target OSes to invoke the commands for.',
    allowed: [...osStrings.values, 'all'],
    defaultsTo: [Abi.current.os.dartPlatform],
  );

  argParser.addMultiOption(
    'abi',
    abbr: 'b',
    help:
        'Target ABIs to invoke the commands for. This overrides `arch` and `os` flags.',
    allowed: [...supportedTargetAbis().map((abi) => abi.toString()), 'all'],
    defaultsTo: [],
  );

  argParser.addOption('verbosity',
      allowed: Level.LEVELS.map((l) => l.name.toLowerCase()),
      defaultsTo: _defaultLevel.name.toLowerCase(),
      help: 'Sets the verbosity level of logging to standard out.');

  argParser.addFlag('verbose',
      abbr: 'v',
      help: "Sets --verbosity to '${_verboseLevel.name.toLowerCase()}'. "
          'Overrides --verbosity and --silent.',
      negatable: false);

  argParser.addFlag('silent',
      abbr: 's',
      help: "Sets --verbosity to '${_silentLevel.name.toLowerCase()}'. "
          'Overrides --verbosity.',
      negatable: false);

  argParser.addCommand(
      'build',
      ArgParser()
        ..addFlag('clean',
            help: 'First run the clean command.', defaultsTo: false)
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
  /// The [Abi]s passed in as argument.
  List<Abi> get abis {
    final validTargets = supportedTargetAbis();
    final abis = _allOrSpecified(
        this['abi'] as List<String>, validTargets, (s) => stringToAbi[s]!);
    if (abis.isNotEmpty) {
      return abis.toList();
    }
    final oses = _allOrSpecified(
        this['os'] as List<String>, OS.values, (s) => stringToOs[s]!);
    final archs = _allOrSpecified(this['arch'] as List<String>,
        Architecture.values, (s) => stringToArchitecture[s]!);
    return [
      for (final os in oses)
        for (final arch in archs)
          if (Abi.isValid(os, arch)) Abi(os, arch)
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
