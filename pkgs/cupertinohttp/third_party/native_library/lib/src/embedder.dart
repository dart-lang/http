import 'dart:io';

import 'package:native_library/src/embedder/embedder.dart' as embedder;
import 'package:package_config/src/package_config_io.dart';

/// The embedders the Dart VM is embedded in.
enum Embedder {
  /// Flutter.
  flutter,

  /// Dart standalone.
  ///
  /// Either through `dart` commandline command or an executable created by
  /// `dart compile exe`.
  standalone,
}

/// Extension on [Embedder].
extension Embedders on Embedder {
  /// The embedder this Dart runtime is embedded in.
  static final Embedder current =
      embedder.isStandalone ? Embedder.standalone : Embedder.flutter;

  /// Whether this embedder is Flutter.
  bool get isFlutter => this == Embedder.flutter;

  /// Whether this embedder is Dart standalone.
  bool get isStandalone => this == Embedder.standalone;
}

/// Whether we're running in precompiled mode.
///
/// Detected by comparing the script and executable.
final bool _runningPrecompiled =
    Platform.script == Uri.file(Platform.resolvedExecutable);

/// The Dart standalone runtime modes.
///
/// Only distinguishing modes relevant for native library loading.
enum StandaloneRuntimeMode {
  /// Running with `dart <script>` or `dart run <package>`.
  ///
  /// Source packages are available in the pub cache.
  jit,

  /// Running an executable compiled with `dart compile exe`.
  ///
  /// Everything, including native libraries, should be bundled in the app.
  executable,
}

/// Extension on [StandaloneRuntimeMode].
extension StandaloneRuntimeModes on StandaloneRuntimeMode {
  /// Infer the runtime mode from the platform running executable.
  ///
  /// Only available in Dart standalone, not available in Flutter.
  static StandaloneRuntimeMode _fromPlatform() {
    if (_runningPrecompiled) {
      return StandaloneRuntimeMode.executable;
    }
    return StandaloneRuntimeMode.jit;
  }

  /// The runtime mode from the platform running executable.
  ///
  /// Only available in Dart standalone, not available in Flutter.
  static final StandaloneRuntimeMode current = _fromPlatform();
}

/// The Flutter embedder runtime modes.
///
/// Only distinguishing modes relevant for native library loading.
enum FlutterRuntimeMode {
  /// Running with `flutter run` or a shipped app.
  ///
  /// Everything, including native libraries, should be bundled in the app.
  app,

  /// Running with `flutter test`.
  ///
  /// Source packages are available in the pub cache.
  test,
}

/// Extension on [FlutterRuntimeMode].
extension FlutterRuntimeModes on FlutterRuntimeMode {
  /// Infer the runtime mode from the platform running executable.
  ///
  /// Only available in Flutter, not available in Dart standalone.
  static FlutterRuntimeMode fromPlatform() {
    final executable = Platform.resolvedExecutable;
    for (final flutterTesterExecutable in _flutterTesterExecutables) {
      if (executable.endsWith(flutterTesterExecutable)) {
        return FlutterRuntimeMode.test;
      }
    }
    return FlutterRuntimeMode.app;
  }

  static final FlutterRuntimeMode current = fromPlatform();
}

const _flutterTesterExecutables = ['flutter_tester', 'flutter_tester.exe'];

/// The synchronous version of `Isolate.packageConfig`.
///
/// Only available in Dart standalone in JIT mode and `flutter test`.
//
// TODO(dacoharkes): Make a feature request for `Isolate.packageConfigSync`.
final Uri packageConfigSync = () {
  if (Embedders.current == Embedder.standalone &&
      StandaloneRuntimeModes.current != StandaloneRuntimeMode.jit) {
    throw UnsupportedError(
        "Not running in JIT, no source package locations available.");
  }
  if (Embedders.current == Embedder.flutter &&
      FlutterRuntimeModes.current != FlutterRuntimeMode.test) {
    throw UnsupportedError(
        "Not running in JIT, no source package locations available.");
  }

  // We cannot use `Platform.script`, because when running
  // `pub run package_a:setup` from `package_b` we want the package_config
  // from `package_b`, not `package_a`.
  Directory directory = Directory.current;

  do {
    final uri = directory.uri.resolve('.dart_tool/package_config.json');
    final packageConfig = File.fromUri(uri);
    if (packageConfig.existsSync()) {
      return uri;
    }
    if (directory.parent == directory) {
      throw "'.dart_tool/package_config.json' not found in any of the parent folders of 'script'.";
    }
    directory = directory.parent;
  } while (true);
}();

/// Finds the source location of a package using `pub`'s package config.
///
/// Only available in Dart standalone in JIT mode.
Uri packageLocation(String packageName) {
  final packageConfigFile = File.fromUri(packageConfigSync);
  // TODO(dacoharkes): Make a PR to add this to the public API.
  final packageConfig = parseAnyConfigFile(
      packageConfigFile.readAsBytesSync(), packageConfigFile.uri, _throwError);
  final package =
      packageConfig.packages.firstWhere((p) => p.name == packageName);
  return package.root;
}

Never _throwError(Object error) => throw error;
